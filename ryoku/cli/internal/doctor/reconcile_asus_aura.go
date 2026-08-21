package doctor

import (
	"os/exec"

	"ryoku-cli/internal/sys"
)

type asusAuraStatus struct {
	supported bool
	installed bool
	tlp       bool
	running   bool
}

var (
	readAsusAuraStatus = probeAsusAuraStatus
	installAsusAura    = func() error {
		return sys.Sudo("pacman", "-S", "--needed", "--noconfirm", "asusctl")
	}
	startAsusAura = func() error {
		return sys.Sudo("systemctl", "start", "asusd.service")
	}
)

func probeAsusAuraStatus() asusAuraStatus {
	st := asusAuraStatus{supported: exec.Command("ryoku-hw-asus-aura").Run() == nil}
	if !st.supported {
		return st
	}
	st.installed = sys.PkgInstalled("asusctl")
	st.tlp = sys.PkgInstalled("tlp")
	st.running = exec.Command("systemctl", "is-active", "--quiet", "asusd.service").Run() == nil
	return st
}

func reconcileAsusAura(checkOnly bool) recResult {
	st := readAsusAuraStatus()
	if !st.supported {
		return okRes("this machine has no supported ASUS Aura laptop controller")
	}
	if !st.installed && st.tlp {
		return warnRes("ASUS Aura keyboard support needs asusctl, which conflicts with the installed TLP power stack").
			withFix("choose TLP or ASUS Aura control; remove TLP before installing asusctl")
	}
	if !st.installed {
		if checkOnly {
			return wouldRes("ASUS Aura keyboard provider is missing").
				withFix("ryoku doctor installs asusctl and starts asusd")
		}
		if err := installAsusAura(); err != nil {
			return failRes("could not install the ASUS Aura provider: %v", err).
				withFix("sudo pacman -S asusctl")
		}
	}
	if st.installed && st.running {
		return okRes("ASUS Aura keyboard provider is installed and running")
	}
	if checkOnly {
		return wouldRes("asusd is installed but not running, so the Aura keyboard is absent from Appearance").
			withFix("ryoku doctor starts asusd")
	}
	if err := startAsusAura(); err != nil {
		return failRes("could not start the ASUS Aura provider: %v", err).
			withFix("sudo systemctl start asusd.service")
	}
	if st.installed {
		return fixedRes("started asusd; the ASUS Aura keyboard is available in Appearance")
	}
	return fixedRes("installed asusctl and started asusd; the ASUS Aura keyboard is available in Appearance")
}
