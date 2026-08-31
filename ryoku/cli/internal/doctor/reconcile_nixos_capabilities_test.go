package doctor

import (
	"os"
	"path/filepath"
	"testing"
)

func writeTestExecutable(t *testing.T, dir, name, body string) {
	t.Helper()

	path := filepath.Join(dir, name)

	if err := os.WriteFile(
		path,
		[]byte("#!/bin/sh\n"+body+"\n"),
		0o755,
	); err != nil {
		t.Fatal(err)
	}
}

func TestMaterialSymbolsAvailableViaFontconfig(t *testing.T) {
	bin := t.TempDir()

	writeTestExecutable(
		t,
		bin,
		"fc-match",
		`printf '%s\n' 'Material Symbols Rounded'`,
	)

	t.Setenv("PATH", bin)

	if !materialSymbolsAvailable() {
		t.Fatal("Fontconfig-visible Material Symbols was reported missing")
	}
}

func TestProbeQMKStatusUsesProviderExecutable(t *testing.T) {
	bin := t.TempDir()

	writeTestExecutable(t, bin, "ryoku-hw-qmk", "exit 0")
	writeTestExecutable(t, bin, "qmk_hid", "exit 0")

	t.Setenv("PATH", bin)

	got := probeQMKStatus()

	if !got.supported {
		t.Fatal("QMK hardware detector was not recognized")
	}

	if !got.installed {
		t.Fatal("qmk_hid executable was not recognized as the provider")
	}
}
