package updater

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"ryoku-cli/internal/sys"
)

var nixSteps = []runStep{
	{Key: "resolve", Label: "Checking Ryoku for NixOS"},
	{Key: "generation", Label: "Building the Ryoku generation"},
	{Key: "finalize", Label: "Finishing up"},
}

func nixBackend() bool {
	return strings.EqualFold(
		strings.TrimSpace(os.Getenv("RYOKU_UPDATE_BACKEND")),
		"nix",
	)
}

func nixVersion() string {
	return strings.TrimSpace(os.Getenv("RYOKU_NIX_VERSION"))
}

func nixChannel() string {
	if ch := strings.TrimSpace(os.Getenv("RYOKU_NIX_CHANNEL")); ch != "" {
		return ch
	}
	return "nix"
}

func nixStatus() statusReport {
	fallback := statusReport{
		Installed: nixVersion(),
		Latest:    nixVersion(),
		Updates:   []updateItem{},
		Recent: []updateItem{
			{
				Name: "Ryoku for NixOS",
				New:  nixVersion(),
			},
		},
		Channel:   nixChannel(),
		Packages:  []updateItem{},
		Backend:   "nix",
		CanUpdate: false,
	}

	out, err := sys.RunOut(
		"ryoku-nix-update",
		"status",
		"--json",
	)
	if err != nil || strings.TrimSpace(out) == "" {
		return fallback
	}

	var report statusReport
	if err := json.Unmarshal([]byte(out), &report); err != nil {
		return fallback
	}

	report.Backend = "nix"

	if report.Updates == nil {
		report.Updates = []updateItem{}
	}
	if report.Recent == nil {
		report.Recent = []updateItem{}
	}
	if report.Packages == nil {
		report.Packages = []updateItem{}
	}

	return report
}

func nixUpdate() error {
	progress.begin(nixSteps)

	progress.at("resolve")
	progress.logf("Checking the Ryoku Nix update channel")

	progress.at("generation")
	progress.logf("Updating only the Ryoku flake input")

	if err := sys.Run("ryoku-nix-update", "update"); err != nil {
		e := fmt.Errorf("Ryoku Nix update failed: %w", err)
		progress.fail(e)
		return e
	}

	progress.at("finalize")
	progress.logf("Ryoku for NixOS update complete")

	return finishRun()
}
