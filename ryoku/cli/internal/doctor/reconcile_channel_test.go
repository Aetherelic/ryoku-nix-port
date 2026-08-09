package doctor

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func gitT(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@e",
		"GIT_COMMITTER_NAME=t", "GIT_COMMITTER_EMAIL=t@e",
		"GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_SYSTEM=/dev/null")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return string(out)
}

// A packaged install has no update-channel checkout, so there is nothing to
// reconcile and the step is a no-op.
func TestReconcileUpdateChannelNoCheckout(t *testing.T) {
	t.Setenv("RYOKU_REPO", "")
	t.Setenv("XDG_STATE_HOME", t.TempDir()) // no recorded repo
	if r := reconcileUpdateChannel(false); r.status != recOK {
		t.Fatalf("packaged box: got %s (%s), want ok", r.status.label(), r.detail)
	}
}

// The core heal: a checkout left on the wrong branch (tracked unstable-dev, but
// sitting on main after a track toggle) is put back on the tracked branch, so
// `ryoku update` stops measuring against the wrong channel.
func TestReconcileUpdateChannelSwitchesToTrackedBranch(t *testing.T) {
	root := t.TempDir()
	origin := filepath.Join(root, "origin.git")
	work := filepath.Join(root, "work")
	if out, err := exec.Command("git", "init", "--bare", "-b", "main", origin).CombinedOutput(); err != nil {
		t.Fatalf("init bare: %v\n%s", err, out)
	}
	if out, err := exec.Command("git", "clone", origin, work).CombinedOutput(); err != nil {
		t.Fatalf("clone: %v\n%s", err, out)
	}
	gitT(t, work, "config", "user.email", "t@e")
	gitT(t, work, "config", "user.name", "t")
	if err := os.WriteFile(filepath.Join(work, "f"), []byte("main\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gitT(t, work, "add", "-A")
	gitT(t, work, "commit", "-m", "main")
	gitT(t, work, "push", "origin", "main")
	gitT(t, work, "checkout", "-b", "unstable-dev")
	if err := os.WriteFile(filepath.Join(work, "f"), []byte("dev\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gitT(t, work, "add", "-A")
	gitT(t, work, "commit", "-m", "dev")
	gitT(t, work, "push", "origin", "unstable-dev")
	gitT(t, work, "checkout", "main") // the "separated" state: on main, tracking unstable-dev

	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	if err := os.MkdirAll(filepath.Join(cfg, "environment.d"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(cfg, "environment.d", "ryoku.conf"), []byte("RYOKU_CHANNEL=unstable-dev\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("RYOKU_REPO", work)

	if r := reconcileUpdateChannel(false); r.status != recFixed {
		t.Fatalf("got %s (%s), want fixed", r.status.label(), r.detail)
	}
	if head := strings.TrimSpace(gitT(t, work, "symbolic-ref", "--short", "HEAD")); head != "unstable-dev" {
		t.Fatalf("checkout on %q, want unstable-dev", head)
	}
}
