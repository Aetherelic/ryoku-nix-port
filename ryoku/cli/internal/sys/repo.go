package sys

import (
	"os"
	"path/filepath"
	"strings"
)

// repoPathFile records where the live-mirror checkout sits. The deployed
// `ryoku` binary lives on PATH with no path back to the repo, so the dev
// deploy (ryoku/shell/deploy.sh) writes the checkout root here.
func repoPathFile() string { return filepath.Join(StateDir(), "repo") }

func recordedRepo() string {
	b, err := os.ReadFile(repoPathFile())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// ResolveRepo returns the Ryoku checkout root to track, or "" when there is
// none (a packaged install). RYOKU_REPO wins (so `ryoku deploy` and tests can
// point it explicitly); else the path the last deploy recorded. Anything that
// is not a git work tree is ignored.
func ResolveRepo() string {
	for _, p := range []string{strings.TrimSpace(os.Getenv("RYOKU_REPO")), recordedRepo()} {
		if p == "" {
			continue
		}
		if _, err := RunOut("git", "-C", p, "rev-parse", "--git-dir"); err == nil {
			return p
		}
	}
	// Fallback: the checkout `ryoku track` clones to, so a lost or broken recorded
	// pointer still self-heals. Gated on the origin so an unrelated repo at that
	// path is never adopted as the update channel.
	track := filepath.Join(Home(), "ryoku-arch")
	if _, err := RunOut("git", "-C", track, "rev-parse", "--git-dir"); err == nil {
		if url, e := RunOut("git", "-C", track, "remote", "get-url", "origin"); e == nil && strings.Contains(url, "ryoku-arch") {
			return track
		}
	}
	return ""
}

// TrackedChannel is the update channel `ryoku track` recorded in
// ~/.config/environment.d/ryoku.conf (a RYOKU_CHANNEL=<branch> line), or "" when
// absent. environment.d is read into the session only at the next login, so the
// live RYOKU_CHANNEL is unset on a just-switched box; reading the file keeps the
// CLI on the tracked channel without waiting for a relogin.
func TrackedChannel() string {
	b, err := os.ReadFile(filepath.Join(ConfigHome(), "environment.d", "ryoku.conf"))
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "RYOKU_CHANNEL=") {
			return strings.TrimSpace(strings.TrimPrefix(line, "RYOKU_CHANNEL="))
		}
	}
	return ""
}
