package doctor

import "testing"

func TestReconcileAsusAuraIgnoresOtherHardware(t *testing.T) {
	withAsusAuraTestState(t, asusAuraStatus{})
	got := reconcileAsusAura(false)
	if got.status != recOK {
		t.Fatalf("status = %v, detail = %s", got.status, got.detail)
	}
}

func TestReconcileAsusAuraInstallsAndStartsProvider(t *testing.T) {
	withAsusAuraTestState(t, asusAuraStatus{supported: true})
	var installed, started bool
	oldInstall, oldStart := installAsusAura, startAsusAura
	installAsusAura = func() error { installed = true; return nil }
	startAsusAura = func() error { started = true; return nil }
	defer func() { installAsusAura, startAsusAura = oldInstall, oldStart }()

	got := reconcileAsusAura(false)
	if got.status != recFixed || !installed || !started {
		t.Fatalf("result = %+v, installed=%v started=%v", got, installed, started)
	}
}

func TestReconcileAsusAuraCheckOnlyAndTLPConflict(t *testing.T) {
	withAsusAuraTestState(t, asusAuraStatus{supported: true})
	if got := reconcileAsusAura(true); got.status != recWouldFix {
		t.Fatalf("check status = %v, detail = %s", got.status, got.detail)
	}

	withAsusAuraTestState(t, asusAuraStatus{supported: true, tlp: true})
	if got := reconcileAsusAura(false); got.status != recWarn {
		t.Fatalf("TLP status = %v, detail = %s", got.status, got.detail)
	}
}

func withAsusAuraTestState(t *testing.T, state asusAuraStatus) {
	t.Helper()
	old := readAsusAuraStatus
	readAsusAuraStatus = func() asusAuraStatus { return state }
	t.Cleanup(func() { readAsusAuraStatus = old })
}
