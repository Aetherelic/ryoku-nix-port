package doctor

import (
	"os"
	"os/exec"
	"strings"

	"ryoku-cli/internal/sys"
)

// ---- reconciler: deliver the hardened rashin daemon to boxes that enabled it -
//
// The rashin agent daemon is opt-in. Boxes that turned it on before the
// hardening shipped are stuck two ways `pacman -Syu` alone cannot fix: the
// pre-hardening unit could trip systemd's default start-limit and park itself
// in `failed` for good (the daemon that "turns off and stays off"), and the
// one-click setup only ever enabled it for login-start, so a headless boot
// leaves the dashboard down (the daemon that "does not turn on"). The package
// lays the new unit file, but only a daemon-reload makes systemd run it on a
// live box, only enable-linger starts it at boot, and only reset-failed clears
// a unit already wedged off. This converges all three. Idempotent, and it never
// turns the daemon on for a user who left it off; retired once every enabled
// box has run it once.

const rashinUserUnit = "ryoku-rashin.service"

// rashinUnitState is the subset of systemd state the reconciler decides on,
// split out so the decision is unit-testable without a live user manager.
type rashinUnitState struct {
	enabled bool
	linger  bool
	failed  bool
}

// rashinDaemonActions decides what an enabled box needs to converge: bring
// boot-start on when lingering is off, and clear a unit wedged into `failed`.
// A disabled unit needs nothing (the daemon is opt-in).
func rashinDaemonActions(s rashinUnitState) (enableLinger, clearFailed bool) {
	if !s.enabled {
		return false, false
	}
	return !s.linger, s.failed
}

func rashinUnitEnabled() bool {
	out, _ := exec.Command("systemctl", "--user", "is-enabled", rashinUserUnit).Output()
	return strings.TrimSpace(string(out)) == "enabled"
}

func rashinUnitFailed() bool {
	out, _ := exec.Command("systemctl", "--user", "is-failed", rashinUserUnit).Output()
	return strings.TrimSpace(string(out)) == "failed"
}

// rashinLingerOn reads the marker systemd-logind maintains for a lingering user,
// which is readable the same whether doctor runs as the user or under sudo.
func rashinLingerOn(user string) bool {
	if user == "" {
		return false
	}
	_, err := os.Stat("/var/lib/systemd/linger/" + user)
	return err == nil
}

func doctorUser() string {
	if u := os.Getenv("USER"); u != "" {
		return u
	}
	return os.Getenv("LOGNAME")
}

func reconcileRashinDaemon(checkOnly bool) recResult {
	if !sys.Has("ryoku-rashin") {
		return okRes("ryoku-rashin not installed")
	}
	if !rashinUnitEnabled() {
		return okRes("rashin daemon is opt-in and not enabled")
	}
	user := doctorUser()
	state := rashinUnitState{enabled: true, linger: rashinLingerOn(user), failed: rashinUnitFailed()}
	enableLinger, clearFailed := rashinDaemonActions(state)
	if !enableLinger && !clearFailed {
		return okRes("rashin daemon enabled with boot-start")
	}
	if checkOnly {
		if clearFailed {
			return wouldRes("the rashin daemon is enabled but wedged off (failed); the dashboard is down").
				withFix("ryoku doctor reloads the hardened unit and restarts it")
		}
		return wouldRes("rashin is enabled but only starts at login; a headless boot leaves the dashboard down").
			withFix("ryoku doctor enables lingering so it starts at boot")
	}
	// daemon-reload so the just-delivered hardened unit is the one systemd runs.
	_ = exec.Command("systemctl", "--user", "daemon-reload").Run()
	var did []string
	if enableLinger {
		if user == "" {
			return failRes("cannot enable rashin boot-start: no login user in the environment").
				withFix("sudo loginctl enable-linger <you>")
		}
		if err := sys.Sudo("loginctl", "enable-linger", user); err != nil {
			return failRes("could not enable lingering for the rashin daemon: %v", err).
				withFix("sudo loginctl enable-linger " + user)
		}
		did = append(did, "enabled boot-start (lingering)")
	}
	if clearFailed {
		_ = exec.Command("systemctl", "--user", "reset-failed", rashinUserUnit).Run()
		did = append(did, "cleared the wedged failed state")
	}
	_ = exec.Command("systemctl", "--user", "start", rashinUserUnit).Run()
	return fixedRes("converged the rashin daemon: " + strings.Join(did, " and ") + ", reloaded the hardened unit")
}
