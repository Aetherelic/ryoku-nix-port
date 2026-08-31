package doctor

import "testing"

// idempotency lock on the NVIDIA reconciler. canonical config we write must
// read back ok (else doctor rebuilds the initramfs every run); pre-fix or
// missing config = "needs fixing".
func TestNvidiaConfigOK(t *testing.T) {
	cases := []struct {
		name             string
		modprobe, mkinit string
		want             bool
	}{
		{"canonical config the reconciler writes", nvidiaModprobeConf, nvidiaMkinitcpioConf, true},
		{"old install: modeset only, no nouveau blacklist", "options nvidia_drm modeset=1 fbdev=1\n", nvidiaMkinitcpioConf, false},
		{"old install: modeset without fbdev heals", "options nvidia_drm modeset=1\nblacklist nouveau\n", nvidiaMkinitcpioConf, false},
		{"blacklisted but nvidia modules not in the initramfs", nvidiaModprobeConf, "", false},
		{"both drop-ins missing (readFileSafe error strings)", "(open /etc/modprobe.d/nvidia.conf: no such file or directory)", "(open /etc/mkinitcpio.conf.d/nvidia.conf: no such file or directory)", false},
	}
	for _, c := range cases {
		if got := nvidiaConfigOK(c.modprobe, c.mkinit); got != c.want {
			t.Errorf("%s: nvidiaConfigOK(...) = %v, want %v", c.name, got, c.want)
		}
	}
}

// idempotency lock on the guard-hook reconciler: the canonical hook must read
// back ok (else doctor rewrites it every run), a stale/absent one must not.
func TestNvidiaGuardHookOK(t *testing.T) {
	cases := []struct {
		name string
		got  string
		want bool
	}{
		{"canonical hook the reconciler writes", nvidiaGuardHook, true},
		{"canonical hook with a trailing newline", nvidiaGuardHook + "\n", true},
		{"pre-fix hook: blind rebuild, no kernel trigger", "[Trigger]\nType=Package\nTarget=nvidia-utils\n[Action]\nExec=/bin/sh -c 'mkinitcpio -P'\n", false},
		{"missing hook (readFileSafe error string)", "(open /etc/pacman.d/hooks/ryoku-nvidia.hook: no such file or directory)", false},
	}
	for _, c := range cases {
		if got := nvidiaGuardHookOK(c.got); got != c.want {
			t.Errorf("%s: nvidiaGuardHookOK(...) = %v, want %v", c.name, got, c.want)
		}
	}
}

func TestNvidiaReconcilersSkipWithoutPacman(t *testing.T) {
	t.Setenv("PATH", t.TempDir())

	for name, reconcile := range map[string]func(bool) recResult{
		"modeset": reconcileNvidiaModeset,
		"guard":   reconcileNvidiaGuardHook,
	} {
		t.Run(name, func(t *testing.T) {
			if got := reconcile(true); got.status != recOK {
				t.Fatalf("status = %v, want ok", got.status)
			}
		})
	}
}
