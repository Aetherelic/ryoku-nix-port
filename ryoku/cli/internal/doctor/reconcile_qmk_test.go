package doctor

import "testing"

func TestReconcileQMKIgnoresOtherHardware(t *testing.T) {
	withQMKTestState(t, qmkStatus{})
	if got := reconcileQMK(false); got.status != recOK {
		t.Fatalf("status = %v, detail = %s", got.status, got.detail)
	}
}

func TestReconcileQMKInstallsWhenBoardPresent(t *testing.T) {
	withQMKTestState(t, qmkStatus{supported: true})
	var installed, reloaded bool
	oldInstall, oldReload := installQMK, reloadQMKUdev
	installQMK = func() error { installed = true; return nil }
	reloadQMKUdev = func() error { reloaded = true; return nil }
	defer func() { installQMK, reloadQMKUdev = oldInstall, oldReload }()

	got := reconcileQMK(false)
	if got.status != recFixed || !installed || !reloaded {
		t.Fatalf("result = %+v, installed=%v reloaded=%v", got, installed, reloaded)
	}
}

func TestReconcileQMKCheckOnlyAndAlreadyInstalled(t *testing.T) {
	withQMKTestState(t, qmkStatus{supported: true})
	if got := reconcileQMK(true); got.status != recWouldFix {
		t.Fatalf("check status = %v, detail = %s", got.status, got.detail)
	}

	withQMKTestState(t, qmkStatus{supported: true, installed: true})
	if got := reconcileQMK(false); got.status != recOK {
		t.Fatalf("installed status = %v, detail = %s", got.status, got.detail)
	}
}

func withQMKTestState(t *testing.T, state qmkStatus) {
	t.Helper()
	old := readQMKStatus
	readQMKStatus = func() qmkStatus { return state }
	t.Cleanup(func() { readQMKStatus = old })
}
