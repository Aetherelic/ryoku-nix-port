package doctor

import (
	"strings"

	"ryoku-cli/internal/sys"
)

// reconcileUpdateChannel heals a box moved between update channels with
// `ryoku track`. track records the channel in ~/.config/environment.d/ryoku.conf
// and checks that branch out in the update checkout (~/ryoku-arch). A toggled or
// half-finished switch can leave the checkout on a different branch than the
// recorded channel; `ryoku update` then measures the running system against the
// wrong branch and shows updates that never clear (and can redeploy a mismatched
// tree, which is where a "shell.qml: File not found" config load comes from).
// Put the checkout back on the tracked branch so status and update agree. Only a
// clean checkout is moved -- a maintainer's uncommitted work is never touched.
func reconcileUpdateChannel(checkOnly bool) recResult {
	repo := sys.ResolveRepo()
	if repo == "" {
		return okRes("packaged install; no update-channel checkout to reconcile")
	}
	ch := sys.TrackedChannel()
	if ch == "" {
		return okRes("no tracked update channel recorded")
	}
	head, _ := sys.RunOut("git", "-C", repo, "symbolic-ref", "--short", "--quiet", "HEAD")
	head = strings.TrimSpace(head)
	if head == ch {
		return okRes("update-channel checkout is on " + ch)
	}
	if checkOnly {
		return wouldRes("the update checkout %s is on %q but the tracked channel is %q; `ryoku update` measures against the wrong branch", repo, head, ch).
			withFix("ryoku doctor")
	}
	if dirty, _ := sys.RunOut("git", "-C", repo, "status", "--porcelain", "--untracked-files=no"); strings.TrimSpace(dirty) != "" {
		return warnRes("%s is on %q, not the tracked channel %q, and has uncommitted changes, so its branch was left as-is", repo, head, ch).
			withFix("commit or stash in %s, then run `ryoku track %s`", repo, ch)
	}
	_, _ = sys.RunOut("git", "-C", repo, "fetch", "origin", ch)
	if _, err := sys.RunOut("git", "-C", repo, "checkout", ch); err != nil {
		return warnRes("could not switch %s onto the tracked channel %q: %v", repo, ch, err).
			withFix("ryoku track %s", ch)
	}
	_, _ = sys.RunOut("git", "-C", repo, "reset", "--hard", "origin/"+ch)
	return fixedRes("switched the update checkout onto the tracked channel %q; run `ryoku update` to redeploy", ch)
}
