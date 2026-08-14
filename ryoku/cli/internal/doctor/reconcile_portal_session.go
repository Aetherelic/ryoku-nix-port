package doctor

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// ---- reconciler: a portal frontend left over from a previous session ----------
//
// xdg-desktop-portal is PartOf=graphical-session.target, but nothing ever stops
// that target: hyprland-session.target only ever starts it, so logging out and
// back in leaves the frontend from the old session running. It then answers for
// a compositor that no longer exists, and a ScreenCast request never reaches the
// hyprland backend -- the D-Bus call times out instead, the source picker never
// opens, and the app is handed nothing. Discord and any Chromium/Electron client
// report the share as simply not working, with no error anywhere the user looks.
//
// The compositor's start time is the reference: a frontend older than the
// Hyprland it is serving cannot have been started for this session. Restarting
// it is enough -- the backend re-registers on demand -- and the autostart's
// try-restart keeps a fresh login from ever getting here.

// parseStartTicks pulls a process's start time (field 22 of /proc/<pid>/stat) out
// of that file's content, in clock ticks since boot. The comm field is a bare
// process name in parentheses and may itself hold spaces and parentheses, so the
// count starts at the LAST ')' instead of splitting the whole line.
func parseStartTicks(stat string) (uint64, bool) {
	paren := strings.LastIndexByte(stat, ')')
	if paren < 0 {
		return 0, false
	}
	// state (field 3) is the first field after comm, so starttime (22) is the
	// 20th of what remains.
	f := strings.Fields(stat[paren+1:])
	if len(f) < 20 {
		return 0, false
	}
	ticks, err := strconv.ParseUint(f[19], 10, 64)
	if err != nil {
		return 0, false
	}
	return ticks, true
}

func procStartTicks(pid int) (uint64, bool) {
	b, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "stat"))
	if err != nil {
		return 0, false
	}
	return parseStartTicks(string(b))
}

// compositorStartTicks is the start time of the session's Hyprland, found by
// walking /proc for a process whose comm is exactly "Hyprland". Read from /proc
// rather than asked of hyprctl, because the whole point is to compare against
// the LIVE compositor even when the caller's HYPRLAND_INSTANCE_SIGNATURE names a
// dead one.
//
// The OLDEST match wins. A nested or newly spawned Hyprland (a plugin test, a
// second compositor in a window) is younger than the portal frontend serving the
// real session, and taking it as the reference would call a perfectly healthy
// frontend stale and restart it out from under a live screen share.
func compositorStartTicks() (uint64, bool) {
	ents, err := os.ReadDir("/proc")
	if err != nil {
		return 0, false
	}
	oldest, found := uint64(0), false
	for _, e := range ents {
		pid, err := strconv.Atoi(e.Name())
		if err != nil {
			continue
		}
		comm, err := os.ReadFile(filepath.Join("/proc", e.Name(), "comm"))
		if err != nil || strings.TrimSpace(string(comm)) != "Hyprland" {
			continue
		}
		if ticks, ok := procStartTicks(pid); ok && (!found || ticks < oldest) {
			oldest, found = ticks, true
		}
	}
	return oldest, found
}

// userUnitMainPID is the MainPID of a --user unit, or 0 when it is not running.
func userUnitMainPID(unit string) int {
	out, err := exec.Command("systemctl", "--user", "show", "-p", "MainPID", "--value", unit).Output()
	if err != nil {
		return 0
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(out)))
	if err != nil {
		return 0
	}
	return pid
}

func reconcilePortalSession(checkOnly bool) recResult {
	hyprStart, ok := compositorStartTicks()
	if !ok {
		return okRes("no running compositor to compare against")
	}
	fePID := userUnitMainPID("xdg-desktop-portal.service")
	if fePID == 0 {
		return okRes("portal frontend not running; it activates fresh on first use")
	}
	feStart, ok := procStartTicks(fePID)
	if !ok {
		return okRes("could not read the portal frontend's start time")
	}
	if feStart >= hyprStart {
		return okRes("portal frontend belongs to this session")
	}
	if checkOnly {
		return wouldRes("the portal frontend predates this Hyprland session; screen share opens no source picker and silently shares nothing").
			withFix("ryoku doctor restarts xdg-desktop-portal")
	}
	if err := exec.Command("systemctl", "--user", "restart", "xdg-desktop-portal.service").Run(); err != nil {
		return failRes("could not restart the portal frontend: %v", err).
			withFix("systemctl --user restart xdg-desktop-portal.service")
	}
	return fixedRes("restarted the portal frontend against this session; screen share picks a source again")
}
