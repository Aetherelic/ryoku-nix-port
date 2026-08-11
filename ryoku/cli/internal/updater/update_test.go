package updater

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// wantedSnapperHelpers gates the offer. no btrfs+snapper -> nothing,
// limine-snapper-sync only on Limine.
func TestWantedSnapperHelpers(t *testing.T) {
	ready := snapHelpers{rootBtrfs: true, snapper: true}

	both := ready
	both.limine = true
	if got := wantedSnapperHelpers(both); len(got) != 2 || got[0] != "snap-pac" || got[1] != "limine-snapper-sync" {
		t.Fatalf("both missing + limine: got %v, want [snap-pac limine-snapper-sync]", got)
	}
	if got := wantedSnapperHelpers(ready); len(got) != 1 || got[0] != "snap-pac" {
		t.Fatalf("no limine: got %v, want [snap-pac]", got)
	}

	hasSnapPac := both
	hasSnapPac.snapPac = true
	if got := wantedSnapperHelpers(hasSnapPac); len(got) != 1 || got[0] != "limine-snapper-sync" {
		t.Fatalf("snap-pac present: got %v, want [limine-snapper-sync]", got)
	}

	allPresent := hasSnapPac
	allPresent.limineSync = true
	if got := wantedSnapperHelpers(allPresent); got != nil {
		t.Fatalf("all present: got %v, want nil", got)
	}

	if got := wantedSnapperHelpers(snapHelpers{snapper: true}); got != nil {
		t.Fatalf("non-btrfs root must offer nothing, got %v", got)
	}
	if got := wantedSnapperHelpers(snapHelpers{rootBtrfs: true}); got != nil {
		t.Fatalf("snapper absent must offer nothing (a separate doctor warn), got %v", got)
	}
}

// publishPrompt/awaitAnswer = the Hub consent back-channel. publish clears
// stale answers, run-state carries the prompt, awaitAnswer reads + consumes.
func TestPromptAnswerRoundTrip(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())

	// stale answer from a previous prompt must not satisfy this one.
	if err := os.WriteFile(answerPath(), []byte("Install"), 0o644); err != nil {
		t.Fatal(err)
	}
	publishPrompt("snapper-helpers", "Enable snapshot helpers?", "detail", []string{"Install", "Skip"})
	if _, err := os.Stat(answerPath()); !os.IsNotExist(err) {
		t.Fatal("publishPrompt must clear a stale answer")
	}

	b, err := os.ReadFile(runStatePath())
	if err != nil || !strings.Contains(string(b), `"phase":"prompt"`) || !strings.Contains(string(b), "snapper-helpers") {
		t.Fatalf("run-state missing the prompt: %s (err %v)", b, err)
	}

	// no answer in the window = decline.
	if choice, ok := awaitAnswer(150 * time.Millisecond); ok {
		t.Fatalf("awaitAnswer should time out with no answer, got %q", choice)
	}

	// written answer: read, then consume.
	if err := os.WriteFile(answerPath(), []byte("Install\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if choice, ok := awaitAnswer(2 * time.Second); !ok || choice != "Install" {
		t.Fatalf("awaitAnswer = %q, %v; want Install, true", choice, ok)
	}
	if _, err := os.Stat(answerPath()); !os.IsNotExist(err) {
		t.Fatal("awaitAnswer must consume the answer file")
	}
}

// An up-to-date packaged box (installed == latest) reports nothing pending but
// lists the recent history the installed commit contains, so the Hub's Updates
// page still has content. packagedStatus is the pure core of buildStatus, so
// this exercises the sha branching and the recent lookup without pacman.
func TestPackagedStatusUpToDatePopulatesRecent(t *testing.T) {
	srv, _ := stubRecent(t, [][2]string{
		{"latest work", "86a91f4aaaa"},
		{"earlier work", "1184abcdddd"},
	})
	t.Setenv("RYOKU_GITHUB_API", srv.URL)
	t.Setenv("RYOKU_REPO_SLUG", "owner/repo")
	t.Setenv("XDG_CACHE_HOME", t.TempDir())

	ver := "0.12.6.r1184.g86a91f4-1" // installed == latest: shortCommit -> 86a91f4
	r := packagedStatus(ver, ver)

	if r.Behind != 0 {
		t.Errorf("pendingUpdates = %d, want 0 when up to date", r.Behind)
	}
	if r.Available {
		t.Error("available = true, want false when up to date")
	}
	if len(r.Updates) != 0 {
		t.Errorf("updates = %d, want 0 (nothing incoming)", len(r.Updates))
	}
	if len(r.Recent) != 2 {
		t.Fatalf("recent = %d, want 2 (from the stub)", len(r.Recent))
	}
	if r.Recent[0].Name != "latest work" || r.Recent[0].New != "86a91f4" {
		t.Errorf("recent[0] = %+v, want {latest work, 86a91f4}", r.Recent[0])
	}
	// The Hub reads these JSON keys off `ryoku status --json`; pin them.
	b, err := json.Marshal(r)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if js := string(b); !strings.Contains(js, `"pendingUpdates":0`) || !strings.Contains(js, `"recent":[{`) {
		t.Errorf("status JSON = %s, want pendingUpdates:0 and a non-empty recent[]", js)
	}
}

// Offline / rate-limited: the recent lookup fails, so the up-to-date report
// degrades to an empty (non-nil) recent list with no error or hang, keeping the
// JSON shape stable.
func TestPackagedStatusUpToDateOfflineEmptyRecent(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	t.Cleanup(srv.Close)
	t.Setenv("RYOKU_GITHUB_API", srv.URL)
	t.Setenv("RYOKU_REPO_SLUG", "owner/repo")
	t.Setenv("XDG_CACHE_HOME", t.TempDir())

	ver := "0.12.6.r1184.g86a91f4-1"
	r := packagedStatus(ver, ver)

	if r.Behind != 0 {
		t.Errorf("pendingUpdates = %d, want 0 when up to date", r.Behind)
	}
	if r.Recent == nil {
		t.Error("recent = nil, want a non-nil empty slice so the JSON stays stable")
	}
	if len(r.Recent) != 0 {
		t.Errorf("recent = %d, want 0 on a failed lookup", len(r.Recent))
	}
}

// systemUpgradeArgs must run an unattended -Syu and --overwrite the Ryoku system
// paths deploy.sh seeds unowned (ryoku-dns / ryoku-wifi-powersave + their polkit
// rules). Once ryoku-desktop packages those paths a file conflict otherwise
// aborts the whole -Syu and blocks every user update; dropping the glob silently
// reintroduces that outage, so pin it here.
func TestSystemUpgradeAdoptsSeededRyokuFiles(t *testing.T) {
	args := systemUpgradeArgs()
	joined := strings.Join(args, " ")
	for _, want := range []string{"pacman -Syu", "--noconfirm", "--overwrite"} {
		if !strings.Contains(joined, want) {
			t.Errorf("systemUpgradeArgs missing %q: %v", want, args)
		}
	}
	var glob string
	for i, a := range args {
		if a == "--overwrite" && i+1 < len(args) {
			glob = args[i+1]
		}
	}
	if glob == "" {
		t.Fatalf("no --overwrite glob in %v", args)
	}
	for _, p := range []string{
		"/usr/bin/ryoku-dns",
		"/usr/bin/ryoku-wifi-powersave",
		"/usr/share/polkit-1/rules.d/50-ryoku-dns.rules",
		"/usr/share/polkit-1/rules.d/49-ryoku-wifi-powersave.rules",
	} {
		covered := false
		for _, g := range strings.Split(glob, ",") {
			if ok, _ := filepath.Match(g, p); ok {
				covered = true
				break
			}
		}
		if !covered {
			t.Errorf("--overwrite %q does not cover deploy.sh-seeded path %q", glob, p)
		}
	}
}
