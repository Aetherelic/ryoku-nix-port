package doctor

import (
	"errors"
	"strings"
	"testing"
)

// stubFlatpak swaps the three seams the reconciler reads, restoring them when the
// test ends. Hermetic: no flatpak binary, no network, no remote is touched.
func stubFlatpak(t *testing.T, configured, reachable bool, addErr error) *int {
	t.Helper()
	oc, or, oa, op := flathubConfigured, flathubReachable, addFlathub, flatpakPresent
	t.Cleanup(func() {
		flathubConfigured, flathubReachable, addFlathub, flatpakPresent = oc, or, oa, op
	})
	flatpakPresent = func() bool { return true }
	adds := 0
	flathubConfigured = func() bool { return configured }
	flathubReachable = func() bool { return reachable }
	addFlathub = func() error { adds++; return addErr }
	return &adds
}

// The reconciler exists because Ryoku ships the flatpak client in the offline
// closure but never configured a remote, so a fresh box had a client and no
// catalogue. The shape that matters most is the offline install: it must stay
// quiet rather than warn about work it cannot do, and it must NOT try to add a
// remote it cannot reach.
func TestFlatpakRemoteReconcile(t *testing.T) {
	cases := []struct {
		name       string
		configured bool
		reachable  bool
		addErr     error
		checkOnly  bool
		wantStatus recStatus
		wantAdds   int
		detailHas  string
	}{
		{
			name:       "already configured is a no-op",
			configured: true, reachable: true,
			wantStatus: recOK, wantAdds: 0, detailHas: "configured",
		},
		{
			name:       "offline install stays quiet and adds nothing",
			configured: false, reachable: false,
			wantStatus: recNote, wantAdds: 0, detailHas: "not reachable",
		},
		{
			name:       "online and missing gets added",
			configured: false, reachable: true,
			wantStatus: recFixed, wantAdds: 1, detailHas: "added the flathub remote",
		},
		{
			name:       "check-only reports without writing",
			configured: false, reachable: true, checkOnly: true,
			wantStatus: recNote, wantAdds: 0, detailHas: "missing",
		},
		{
			name:       "a failed add warns with a hand fix",
			configured: false, reachable: true, addErr: errors.New("boom"),
			wantStatus: recWarn, wantAdds: 1, detailHas: "could not add",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			adds := stubFlatpak(t, c.configured, c.reachable, c.addErr)
			got := reconcileFlatpakRemote(c.checkOnly)
			if got.status != c.wantStatus {
				t.Errorf("status = %v, want %v (detail: %s)", got.status, c.wantStatus, got.detail)
			}
			if *adds != c.wantAdds {
				t.Errorf("addFlathub called %d time(s), want %d", *adds, c.wantAdds)
			}
			if !strings.Contains(got.detail, c.detailHas) {
				t.Errorf("detail %q does not mention %q", got.detail, c.detailHas)
			}
		})
	}
}

// An offline install must never be told to fix something it cannot fix, so the
// unreachable case carries a remedy that names the condition (a network) rather
// than a command that would fail.
func TestFlatpakOfflineRemedyNamesTheNetwork(t *testing.T) {
	stubFlatpak(t, false, false, nil)
	got := reconcileFlatpakRemote(false)
	if !strings.Contains(got.remedy, "network") {
		t.Errorf("remedy %q should name the network as the prerequisite", got.remedy)
	}
}
