package doctor

import (
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

// TestReconcileObsidianSnippet covers the guard (no vault -> no-op), the install
// (snippet symlink + enable), preservation of a user's other snippets, and
// idempotency.
func TestReconcileObsidianSnippet(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))

	if r := reconcileObsidianSnippet(false); r.status != recOK {
		t.Fatalf("no config: status=%s want ok", r.status.label())
	}

	cfg := filepath.Join(home, ".config")
	generated := filepath.Join(cfg, "matugen", "generated", "obsidian.css")
	browserMkdir(t, filepath.Dir(generated))
	if err := os.WriteFile(generated, []byte(".theme-dark{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	vault := filepath.Join(home, "vault")
	browserMkdir(t, filepath.Join(vault, ".obsidian"))
	// a pre-existing user snippet the reconciler must not drop
	if err := os.WriteFile(filepath.Join(vault, ".obsidian", "appearance.json"), []byte(`{"enabledCssSnippets":["mine"]}`), 0o644); err != nil {
		t.Fatal(err)
	}
	browserMkdir(t, filepath.Join(cfg, "obsidian"))
	if err := os.WriteFile(filepath.Join(cfg, "obsidian", "obsidian.json"),
		[]byte(`{"vaults":{"abc":{"path":`+strconv.Quote(vault)+`}}}`), 0o644); err != nil {
		t.Fatal(err)
	}

	r := reconcileObsidianSnippet(false)
	if r.status != recFixed {
		t.Fatalf("install: status=%s want fixed (detail=%s)", r.status.label(), r.detail)
	}
	link := filepath.Join(vault, ".obsidian", "snippets", "ryoku.css")
	if tgt, err := os.Readlink(link); err != nil || tgt != generated {
		t.Fatalf("snippet link=%q err=%v want -> %s", tgt, err, generated)
	}
	ap := browserReadManifest(t, filepath.Join(vault, ".obsidian", "appearance.json"))
	snips, _ := ap["enabledCssSnippets"].([]any)
	hasRyoku, hasMine := false, false
	for _, s := range snips {
		if s == "ryoku" {
			hasRyoku = true
		}
		if s == "mine" {
			hasMine = true
		}
	}
	if !hasRyoku || !hasMine {
		t.Fatalf("enabledCssSnippets=%v want both ryoku and mine", snips)
	}

	if r2 := reconcileObsidianSnippet(false); r2.status != recOK {
		t.Fatalf("second run: status=%s want ok (detail=%s)", r2.status.label(), r2.detail)
	}
}
