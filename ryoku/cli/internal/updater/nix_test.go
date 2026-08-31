package updater

import (
	"os"
	"path/filepath"
	"testing"
)

func writeNixUpdateHelper(t *testing.T, body string) string {
	t.Helper()

	dir := t.TempDir()
	path := filepath.Join(dir, "ryoku-nix-update")

	if err := os.WriteFile(
		path,
		[]byte("#!/bin/sh\n"+body+"\n"),
		0o755,
	); err != nil {
		t.Fatal(err)
	}

	return dir
}

func TestNixStatusUsesNixHelper(t *testing.T) {
	bin := writeNixUpdateHelper(t, `printf '%s\n' '{"installedVersion":"0.48.8-beta.18","latestVersion":"0.48.8-beta.19","available":true,"pendingUpdates":1,"updates":[{"name":"Ryoku for NixOS","old":"0.48.8-beta.18","new":"0.48.8-beta.19"}],"recent":[],"channel":"nixos-port-review","snapshots":0,"packages":[],"backend":"nix","canUpdate":true,"source":"github:example/ryoku/nixos-port-review"}'`)

	t.Setenv("PATH", bin)
	t.Setenv("RYOKU_UPDATE_BACKEND", "nix")
	t.Setenv("RYOKU_NIX_VERSION", "0.48.8-beta.18")

	got := buildStatus()

	if got.Backend != "nix" {
		t.Fatalf("backend = %q, want nix", got.Backend)
	}
	if got.Installed != "0.48.8-beta.18" {
		t.Fatalf("installed = %q", got.Installed)
	}
	if got.Latest != "0.48.8-beta.19" {
		t.Fatalf("latest = %q", got.Latest)
	}
	if !got.Available || !got.CanUpdate {
		t.Fatalf("availability = %+v", got)
	}
	if len(got.Packages) != 0 {
		t.Fatalf("Nix status exposed system packages: %+v", got.Packages)
	}
}

func TestNixStatusFallbackDoesNotUseArchPackages(t *testing.T) {
	t.Setenv("PATH", t.TempDir())
	t.Setenv("RYOKU_UPDATE_BACKEND", "nix")
	t.Setenv("RYOKU_NIX_VERSION", "0.48.8-beta.18")

	got := buildStatus()

	if got.Backend != "nix" {
		t.Fatalf("backend = %q, want nix", got.Backend)
	}
	if got.Installed != "0.48.8-beta.18" ||
		got.Latest != "0.48.8-beta.18" {
		t.Fatalf("fallback versions = %+v", got)
	}
	if got.Available {
		t.Fatal("fallback reported an update")
	}
	if len(got.Packages) != 0 {
		t.Fatalf("fallback exposed Arch packages: %+v", got.Packages)
	}
}
