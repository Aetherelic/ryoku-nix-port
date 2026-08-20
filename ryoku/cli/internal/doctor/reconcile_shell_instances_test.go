package doctor

import (
	"bufio"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"testing"
	"time"
)

func TestQuickshellConfigReadsBothSelectorForms(t *testing.T) {
	for _, tc := range []struct {
		name   string
		argv   []string
		config string
		ok     bool
	}{
		{"packaged desktop", []string{"qs", "-c", "shell"}, "shell", true},
		{"checkout desktop", []string{"qs", "-p", "/repo/ryoku/shell/quickshell/shell"}, "shell", true},
		{"long flag", []string{"/usr/bin/qs", "--config", "shell"}, "shell", true},
		{"the other binary name", []string{"/usr/bin/quickshell", "-c", "shell"}, "shell", true},
		{"an app, not the desktop", []string{"qs", "-c", "ryowalls"}, "ryowalls", true},
		{"an ipc client is not an instance", []string{"qs", "-c", "shell", "ipc", "call", "bar", "hide"}, "", false},
		{"another program", []string{"sleep", "-c", "shell"}, "", false},
		{"no selector", []string{"qs", "ipc", "call"}, "", false},
	} {
		config, ok := quickshellConfig(tc.argv)
		if ok != tc.ok || config != tc.config {
			t.Errorf("%s: quickshellConfig(%v) = %q,%v want %q,%v", tc.name, tc.argv, config, ok, tc.config, tc.ok)
		}
	}
}

// The keeper must be the desktop the user is looking at: the one the supervising
// daemon started. Killing the wrong one would black out a working session.
func TestPickLiveShellKeepsTheSupervisedInstance(t *testing.T) {
	found := []shellInstance{
		{pid: 4000, ppid: 1, config: "shell"},    // orphan from a killed daemon
		{pid: 4100, ppid: 3000, config: "shell"}, // started by the live unit
	}
	keep, strays := pickLiveShell(found, 3000, map[int]bool{3000: true})
	if keep != 4100 {
		t.Fatalf("kept pid %d, want the unit's child 4100", keep)
	}
	if len(strays) != 1 || strays[0].pid != 4000 {
		t.Fatalf("strays = %+v, want just the orphan 4000", strays)
	}
}

// A dev checkout runs the daemon outside systemd, so there is no unit MainPID to
// match; the daemon's own child still wins.
func TestPickLiveShellFallsBackToAnyLiveDaemon(t *testing.T) {
	found := []shellInstance{
		{pid: 5100, ppid: 5000, config: "shell"},
		{pid: 5200, ppid: 1, config: "shell"},
	}
	keep, strays := pickLiveShell(found, 0, map[int]bool{5000: true})
	if keep != 5100 || len(strays) != 1 || strays[0].pid != 5200 {
		t.Fatalf("keep=%d strays=%+v; want 5100 kept and 5200 stray", keep, strays)
	}
}

func TestPickLiveShellSingleInstanceHasNoStrays(t *testing.T) {
	keep, strays := pickLiveShell([]shellInstance{{pid: 7, ppid: 1}}, 0, nil)
	if keep != 7 || len(strays) != 0 {
		t.Fatalf("keep=%d strays=%+v; a lone instance is the desktop", keep, strays)
	}
	if keep, strays := pickLiveShell(nil, 0, nil); keep != 0 || strays != nil {
		t.Fatalf("empty input must yield nothing: %d %+v", keep, strays)
	}
}

// Both orphaned: the older one is the session's desktop, the newer was drawn on
// top of it.
func TestPickLiveShellPrefersTheOlderOrphan(t *testing.T) {
	older, newer := spawnSleeper(t), spawnSleeper(t)
	found := []shellInstance{
		{pid: newer, ppid: 1, config: "shell"},
		{pid: older, ppid: 1, config: "shell"},
	}
	keep, strays := pickLiveShell(found, 0, map[int]bool{})
	if keep != older {
		t.Fatalf("kept pid %d, want the older instance %d", keep, older)
	}
	if len(strays) != 1 || strays[0].pid != newer {
		t.Fatalf("strays = %+v, want the newer instance %d", strays, newer)
	}
}

func TestLivePidsIgnoresTheDead(t *testing.T) {
	pid := spawnSleeper(t)
	if got := livePids([]int{pid}); len(got) != 1 || got[0] != pid {
		t.Fatalf("livePids = %v, want [%d]", got, pid)
	}
	if got := livePids([]int{pid, 999999}); len(got) != 1 {
		t.Fatalf("a pid that does not exist must not count as live: %v", got)
	}
}

// killShellInstances has to end a duplicate that ignores SIGTERM, because a
// wedged Quickshell is how the duplicate survived in the first place.
func TestKillShellInstancesEndsAStubbornDuplicate(t *testing.T) {
	cmd := exec.Command("sh", "-c", "trap '' TERM; echo armed; while :; do sleep 0.2; done")
	out, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	pid := cmd.Process.Pid
	t.Cleanup(func() { _ = cmd.Process.Kill() })
	if _, err := bufio.NewReader(out).ReadString('\n'); err != nil {
		t.Fatalf("subject never armed: %v", err)
	}
	go func() { _ = cmd.Wait() }()

	killShellInstances([]int{pid})
	if left := livePids([]int{pid}); len(left) != 0 {
		t.Fatalf("duplicate %v survived the reap", left)
	}
}

func TestProcPPIDReadsTheParent(t *testing.T) {
	pid := spawnSleeper(t)
	if got := procPPID(pid); got != os.Getpid() {
		t.Fatalf("procPPID(%d) = %d, want this test process %d", pid, got, os.Getpid())
	}
	if got := procPPID(999999); got != 0 {
		t.Fatalf("a missing process has no parent, got %d", got)
	}
}

// A machine with one desktop (or none) must come back clean, and check-only must
// never touch a process.
func TestReconcileShellInstancesQuietWhenSingle(t *testing.T) {
	res := reconcileShellInstances(true)
	switch res.status {
	case recOK, recWouldFix:
	default:
		t.Fatalf("unexpected status %v: %s", res.status, res.detail)
	}
	if res.status == recOK && res.detail == "" {
		t.Fatal("an ok result still has to say what it checked")
	}
}

func TestDaemonPidsFindsNothingUnexpected(t *testing.T) {
	// The map is keyed by pid; every entry must be a live process.
	for pid := range daemonPids() {
		if len(livePids([]int{pid})) != 1 {
			t.Fatalf("daemonPids reported pid %d, which is not live", pid)
		}
	}
}

// spawnSleeper starts a short-lived child and returns its pid, ordered so that
// two calls give an older and a newer process.
func spawnSleeper(t *testing.T) int {
	t.Helper()
	cmd := exec.Command("sleep", "30")
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = cmd.Process.Signal(syscall.SIGKILL)
		_ = cmd.Wait()
	})
	// clock ticks are coarse (100 Hz), so space the two births apart or their
	// start times compare equal.
	time.Sleep(20 * time.Millisecond)
	if _, err := os.Stat(filepath.Join("/proc", "self")); err != nil {
		t.Skip("no /proc on this machine")
	}
	return cmd.Process.Pid
}
