package doctor

import "testing"

func TestRashinDaemonActions(t *testing.T) {
	cases := []struct {
		name              string
		state             rashinUnitState
		wantLinger, wantFailed bool
	}{
		{"disabled does nothing", rashinUnitState{enabled: false, linger: false, failed: true}, false, false},
		{"enabled no linger enables boot-start", rashinUnitState{enabled: true, linger: false, failed: false}, true, false},
		{"enabled wedged clears failed", rashinUnitState{enabled: true, linger: true, failed: true}, false, true},
		{"enabled off and wedged does both", rashinUnitState{enabled: true, linger: false, failed: true}, true, true},
		{"enabled and converged does nothing", rashinUnitState{enabled: true, linger: true, failed: false}, false, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			gotLinger, gotFailed := rashinDaemonActions(c.state)
			if gotLinger != c.wantLinger || gotFailed != c.wantFailed {
				t.Fatalf("rashinDaemonActions(%+v) = (linger=%v, failed=%v), want (linger=%v, failed=%v)",
					c.state, gotLinger, gotFailed, c.wantLinger, c.wantFailed)
			}
		})
	}
}
