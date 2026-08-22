package doctor

import (
	"fmt"
	"os"
	"strings"

	"ryoku-cli/internal/sys"
)

// one `snapper delete` handles at most this many: a huge batch can time out
// over D-Bus partway and strand the rest.
const snapshotDrainBatch = 20

// reconcileSnapperCleanup keeps pruning working. Pruning normally runs only via
// snapper-cleanup.timer -> snapper-cleanup.service, whose success is coupled to
// limine-snapper-sync (its ExecStopPost); when that breaks nothing is pruned
// and every update leaves another unremovable pair. So keep the cleanup timer
// on, the timeline timer off (Ryoku prunes by number, and Cleanup=timeline
// snapshots leak past number cleanup), and drain leaked timeline snapshots.
// Draining runs only under a number-only config (TIMELINE_CREATE="no").
func reconcileSnapperCleanup(checkOnly bool) recResult {
	if !sys.Exists("/etc/snapper/configs/root") {
		return okRes("root snapshots not configured, nothing to prune")
	}
	if !sys.Has("snapper") {
		return okRes("snapper is not installed, so there is nothing to prune")
	}

	cleanupOff := !sys.UnitEnabled("snapper-cleanup.timer")
	timelineOn := sys.UnitEnabled("snapper-timeline.timer")
	numberOnly := snapperTimelineOff()
	var leaked []string
	if numberOnly {
		leaked = leakedTimelineSnapshots()
	}

	if checkOnly {
		switch {
		case cleanupOff:
			return wouldRes("snapper-cleanup.timer is disabled, so snapshots are never pruned on a schedule").
				withFix("ryoku doctor (enables snapper-cleanup.timer)")
		case timelineOn && numberOnly:
			return wouldRes("snapper-timeline.timer is enabled; Ryoku prunes by number only, so timeline snapshots leak").
				withFix("ryoku doctor (disables snapper-timeline.timer)")
		case len(leaked) > 0:
			return wouldRes("%d leaked timeline snapshot(s) that number cleanup never reclaims", len(leaked)).
				withFix("ryoku doctor (deletes them in batches, then runs snapper cleanup number)")
		}
		return okRes("snapshot cleanup is healthy")
	}

	var fixes []string
	if cleanupOff {
		if err := sys.Run("sudo", "systemctl", "enable", "--now", "snapper-cleanup.timer"); err == nil {
			fixes = append(fixes, "enabled snapper-cleanup.timer")
		}
	}
	if timelineOn && numberOnly {
		if err := sys.Run("sudo", "systemctl", "disable", "--now", "snapper-timeline.timer"); err == nil {
			fixes = append(fixes, "disabled snapper-timeline.timer")
		}
	}
	if len(leaked) > 0 {
		deleted, failed := drainSnapshots(leaked, snapshotDrainBatch)
		if deleted > 0 {
			fixes = append(fixes, fmt.Sprintf("deleted %d leaked timeline snapshot(s)", deleted))
		}
		if failed > 0 {
			fixes = append(fixes, fmt.Sprintf("%d timeline snapshot(s) could not be deleted (retry: sudo snapper -c root cleanup number)", failed))
		}
	}
	// catch the numbered pile up now, not at the next timer tick.
	if len(fixes) > 0 {
		_ = sys.Run("sudo", "snapper", "-c", "root", "cleanup", "number")
	}

	if len(fixes) == 0 {
		return okRes("snapshot cleanup is healthy")
	}
	return fixedRes("%s", strings.Join(fixes, "; "))
}

// snapperTimelineOff reports number-only cleanup. The config is 0640 root:root,
// so fall back to a cached sudo read; an unreadable config reads as "not off"
// so the drain never fires on a guess.
func snapperTimelineOff() bool {
	b, err := os.ReadFile("/etc/snapper/configs/root")
	contents := string(b)
	if err != nil {
		contents, _ = sys.RunOut("sudo", "-n", "cat", "/etc/snapper/configs/root")
	}
	return configTimelineOff(contents)
}

func configTimelineOff(contents string) bool {
	for _, line := range strings.Split(contents, "\n") {
		if strings.TrimSpace(line) == `TIMELINE_CREATE="no"` {
			return true
		}
	}
	return false
}

// leakedTimelineSnapshots lists Cleanup=timeline numbers, read-only and
// non-prompting; a machine that cannot answer yields nothing to drain.
func leakedTimelineSnapshots() []string {
	out, err := sys.RunOut("sudo", "-n", "snapper", "-c", "root", "--csvout",
		"list", "--columns", "number,cleanup")
	if err != nil {
		return nil
	}
	return parseLeakedTimeline(out)
}

// parseLeakedTimeline returns timeline-cleanup numbers, skipping the header and
// the base snapshot 0.
func parseLeakedTimeline(csv string) []string {
	var out []string
	for _, line := range strings.Split(csv, "\n") {
		fields := strings.Split(strings.TrimSpace(line), ",")
		if len(fields) < 2 {
			continue
		}
		num, cleanup := strings.TrimSpace(fields[0]), strings.TrimSpace(fields[1])
		if num == "" || num == "0" || !allDigits(num) {
			continue
		}
		if cleanup == "timeline" {
			out = append(out, num)
		}
	}
	return out
}

// drainSnapshots deletes numbers in batches, tolerating a failed batch so the
// rest still drain.
func drainSnapshots(numbers []string, size int) (deleted, failed int) {
	for _, batch := range chunk(numbers, size) {
		args := append([]string{"snapper", "-c", "root", "delete"}, batch...)
		if err := sys.Sudo(args...); err != nil {
			failed += len(batch)
		} else {
			deleted += len(batch)
		}
	}
	return deleted, failed
}

func chunk(s []string, size int) [][]string {
	if size <= 0 {
		size = len(s)
	}
	var out [][]string
	for i := 0; i < len(s); i += size {
		end := i + size
		if end > len(s) {
			end = len(s)
		}
		out = append(out, s[i:end])
	}
	return out
}

func allDigits(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// reconcileUpdatedbPrune stops plocate/mlocate indexing every file under
// /.snapshots, which turns updatedb into an hours-long crawl on a
// snapshot-heavy box. No updatedb.conf means locate is not installed.
func reconcileUpdatedbPrune(checkOnly bool) recResult {
	const path = "/etc/updatedb.conf"
	if !sys.Exists(path) {
		return okRes("no /etc/updatedb.conf (locate not installed)")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return okRes("cannot read %s (%v); leaving it alone", path, err)
	}
	next, changed := addUpdatedbPrunePath(string(b), "/.snapshots")
	if !changed {
		return okRes("updatedb already skips /.snapshots")
	}
	if checkOnly {
		return wouldRes("updatedb indexes /.snapshots, so plocate crawls every snapshot").
			withFix("ryoku doctor (adds /.snapshots to PRUNEPATHS in /etc/updatedb.conf)")
	}
	if err := writeRootFile(path, next, "0644"); err != nil {
		return failRes("updating %s: %v", path, err)
	}
	return fixedRes("added /.snapshots to updatedb PRUNEPATHS so plocate skips snapshots")
}

// addUpdatedbPrunePath ensures path is in PRUNEPATHS, extending an existing
// line or appending one; changed=false when already listed.
func addUpdatedbPrunePath(conf, path string) (string, bool) {
	lines := strings.Split(conf, "\n")
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "PRUNEPATHS=") {
			continue
		}
		val := strings.Trim(strings.TrimPrefix(trimmed, "PRUNEPATHS="), `"`)
		for _, f := range strings.Fields(val) {
			if f == path {
				return conf, false
			}
		}
		lines[i] = `PRUNEPATHS="` + strings.Join(append(strings.Fields(val), path), " ") + `"`
		return strings.Join(lines, "\n"), true
	}
	out := conf
	if out != "" && !strings.HasSuffix(out, "\n") {
		out += "\n"
	}
	return out + `PRUNEPATHS="` + path + `"` + "\n", true
}
