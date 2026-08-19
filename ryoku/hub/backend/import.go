package main

// Config import: bring a migrating user's existing dotfiles onto Ryoku without
// losing them and without breaking the desktop. `import scan` reports what was
// found (apps, items, keybind conflicts) as JSON; `import apply` layers the
// chosen config on top of Ryoku's defaults (Hyprland binds/rules into the hub
// Overrides model, everything else into each app's user-include) after a full
// backup; `import undo` restores a prior import from that backup. The verbs and
// JSON are the cross-slice contract shared with the CLI and Hub UI; see
// docs/config-import.md.
//
// This file owns the verb dispatch, the scan orchestration, and the pieces both
// scan and apply share: combo normalization and Ryoku's shipped-bind legend.
// import_parse.go has the per-app parsers, import_apply.go the apply + backup,
// import_undo.go the restore.

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// --- JSON contract (lowerCamel field names are the cross-slice interface) ----

type scanResult struct {
	Source string    `json:"source"`
	Apps   []scanApp `json:"apps"`
}

type scanApp struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Present   bool           `json:"present"`
	Path      string         `json:"path"`
	Tier      string         `json:"tier"` // deep | layer | drop
	Summary   string         `json:"summary"`
	Items     []scanItem     `json:"items"`
	Conflicts []scanConflict `json:"conflicts"`
}

type scanItem struct {
	Kind       string `json:"kind"` // bind|windowrule|monitor|env|exec|setting|raw|file
	Raw        string `json:"raw"`
	Combo      string `json:"combo,omitempty"`      // bind only, display form
	Dispatcher string `json:"dispatcher,omitempty"` // bind only, native token
	Ingestable bool   `json:"ingestable"`
}

type scanConflict struct {
	Combo string        `json:"combo"` // display form
	Norm  string        `json:"norm"`  // stable key, opaque to UI/CLI
	Ryoku conflictRyoku `json:"ryoku"`
	Mine  conflictMine  `json:"mine"`
	Kind  string        `json:"kind"` // shipped | duplicate
}

type conflictRyoku struct {
	Action string `json:"action"`
	Desc   string `json:"desc"`
}

type conflictMine struct {
	Raw  string `json:"raw"`
	Desc string `json:"desc"`
}

// decisions is the apply input. An app absent or include:false is skipped; a
// conflict absent from Conflicts defaults to "ryoku" (Ryoku's bind kept).
type decisions struct {
	Source    string                     `json:"source"`
	Apps      map[string]appDecision     `json:"apps"`
	Conflicts map[string]json.RawMessage `json:"conflicts"`
}

type appDecision struct {
	Include bool `json:"include"`
}

type applyResult struct {
	Ts            string   `json:"ts"`
	BackupDir     string   `json:"backupDir"`
	FilesWritten  []string `json:"filesWritten"`
	BindsIngested int      `json:"bindsIngested"`
	RulesIngested int      `json:"rulesIngested"`
	Unbinds       int      `json:"unbinds"`

	// Unresolved lists imported bind lines whose dispatcher has no hl.dsp
	// translation, so they were preserved as a "port by hand" comment and did
	// not take effect (and never triggered an unbind of a shipped chord).
	Unresolved []string `json:"unresolved,omitempty"`
}

type undoResult struct {
	Ts       string   `json:"ts"`
	Restored []string `json:"restored"`
}

type importManifest struct {
	Ts       string         `json:"ts"`
	Snapshot string         `json:"snapshot,omitempty"`
	Files    []manifestFile `json:"files"`
}

// manifestFile records one backed-up file. Backup is empty when the file did
// not exist before the import, so undo removes it instead of restoring bytes.
type manifestFile struct {
	Path   string `json:"path"`
	Backup string `json:"backup"`
}

// --- verb dispatch -----------------------------------------------------------

func runImport(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("import needs scan|apply|undo")
	}
	switch args[0] {
	case "scan":
		if len(args) < 2 {
			return fmt.Errorf("import scan needs a path or url")
		}
		src, err := resolveSource(args[1])
		if err != nil {
			return err
		}
		return printJSON(scanSource(src))
	case "apply":
		if len(args) < 2 {
			return fmt.Errorf("import apply needs a decisions file or -")
		}
		dec, err := readDecisions(args[1])
		if err != nil {
			return err
		}
		res, err := applyImport(dec)
		if err != nil {
			return err
		}
		return printJSON(res)
	case "undo":
		ts := ""
		if len(args) > 1 {
			ts = args[1]
		}
		res, err := undoImport(ts)
		if err != nil {
			return err
		}
		return printJSON(res)
	default:
		return fmt.Errorf("unknown import subcommand: %s", args[0])
	}
}

// resolveSource turns the scan argument into a local directory. A git URL is
// cloned to a temp dir whose path is returned as the ScanResult source, so apply
// can reuse it; a plain path is made absolute and must exist.
func resolveSource(arg string) (string, error) {
	if isGitURL(arg) {
		dir, err := os.MkdirTemp("", "ryoku-import-*")
		if err != nil {
			return "", err
		}
		cmd := exec.Command("git", "clone", "--depth", "1", arg, dir)
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return "", fmt.Errorf("clone %s: %w", arg, err)
		}
		return dir, nil
	}
	abs, err := filepath.Abs(arg)
	if err != nil {
		return "", err
	}
	if _, err := os.Stat(abs); err != nil {
		return "", fmt.Errorf("source not found: %s", abs)
	}
	return abs, nil
}

func isGitURL(s string) bool {
	return strings.Contains(s, "://") ||
		strings.HasPrefix(s, "git@") ||
		strings.HasSuffix(s, ".git")
}

func readDecisions(arg string) (decisions, error) {
	var b []byte
	var err error
	if arg == "-" {
		b, err = io.ReadAll(os.Stdin)
	} else {
		b, err = os.ReadFile(arg)
	}
	if err != nil {
		return decisions{}, err
	}
	var d decisions
	if err := json.Unmarshal(b, &d); err != nil {
		return decisions{}, fmt.Errorf("parse decisions: %w", err)
	}
	return d, nil
}

// --- scan orchestration ------------------------------------------------------

// knownApps are the apps with a first-class parser or layer target, in the order
// they appear in the review UI. Anything else the user brought is a generic drop.
var knownApps = map[string]bool{"hypr": true, "kitty": true, "fish": true, "fastfetch": true}

func scanSource(source string) scanResult {
	res := scanResult{Source: source, Apps: []scanApp{}}
	if a, ok := scanHyprland(source); ok {
		res.Apps = append(res.Apps, a)
	}
	if a, ok := scanKitty(source); ok {
		res.Apps = append(res.Apps, a)
	}
	if a, ok := scanFish(source); ok {
		res.Apps = append(res.Apps, a)
	}
	if a, ok := scanFastfetch(source); ok {
		res.Apps = append(res.Apps, a)
	}
	res.Apps = append(res.Apps, scanGeneric(source)...)
	return res
}

// findConfig returns the first existing candidate under the source, trying the
// bare dir, a <name>/ subdir, and a nested .config/<name>/ so a raw dotfiles
// tree, a config-home export, and a whole home directory all work.
func findConfig(source, dir, file string) (string, bool) {
	for _, cand := range []string{
		filepath.Join(source, dir, file),
		filepath.Join(source, ".config", dir, file),
		filepath.Join(source, file),
	} {
		if st, err := os.Stat(cand); err == nil && !st.IsDir() {
			return cand, true
		}
	}
	return "", false
}

// --- combo normalization (shared by scan conflict detection and apply) -------

// normCombo maps a display combo ("SUPER + Q") to a stable, order-independent
// key ("q+super"): modifiers canonicalized, everything lowercased, tokens
// sorted. Two combos collide iff they bind the same chord, whatever the source
// wrote for the modifier or the token order.
func normCombo(combo string) string {
	var toks []string
	for _, p := range strings.Split(combo, "+") {
		if p = strings.TrimSpace(p); p != "" {
			toks = append(toks, normToken(p))
		}
	}
	sort.Strings(toks)
	return strings.Join(toks, "+")
}

func normToken(t string) string {
	switch strings.ToUpper(t) {
	case "SUPER", "MOD", "MAINMOD", "WIN", "META", "LOGO", "SUPER_L", "SUPER_R":
		return "super"
	case "CTRL", "CONTROL", "CONTROL_L", "CONTROL_R":
		return "ctrl"
	case "ALT", "MOD1", "ALT_L", "ALT_R":
		return "alt"
	case "SHIFT", "SHIFT_L", "SHIFT_R":
		return "shift"
	}
	return strings.ToLower(t)
}

// --- Ryoku's shipped bind legend (for conflict detection + unbinds) ----------

// shippedInfo is one shipped chord: Combo is the raw form hl.unbind() keys on,
// Action/Desc describe it for the conflict UI.
type shippedInfo struct {
	Combo  string
	Action string
	Desc   string
}

// ryokuShipped reads binds.lua (Ryoku's live legend, the same file keybinds()
// serves) into norm -> shippedInfo. It walks the file directly rather than
// reusing keybinds() because conflict rows need the dispatcher, which the legend
// drops; the parsing helpers (resolveKeys, describe, reBind/reTrail) are shared.
// The workspace loop is expanded to its ten concrete chords so a Super+N import
// is caught as a shadow.
func ryokuShipped() map[string]shippedInfo {
	out := map[string]shippedInfo{}
	b, err := os.ReadFile(bindsPath())
	if err != nil {
		return out
	}
	add := func(combo, action, desc string) {
		if combo == "" {
			return
		}
		n := normCombo(combo)
		if _, ok := out[n]; !ok {
			out[n] = shippedInfo{Combo: combo, Action: action, Desc: desc}
		}
	}
	inLoop := false
	for _, line := range strings.Split(string(b), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "for ") {
			inLoop = true
			continue
		}
		if inLoop && trimmed == "end" {
			inLoop = false
			continue
		}
		if !strings.Contains(trimmed, "hl.bind(") {
			continue
		}
		m := reBind.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		comment := ""
		if cm := reTrail.FindStringSubmatch(line); cm != nil {
			comment = cm[1]
		}
		action := dispatcherAction(m[2])
		desc := describe(comment, m[2])
		if inLoop {
			for i := 1; i <= 10; i++ {
				_, combo := resolveKeys(m[1], fmt.Sprint(i%10))
				add(combo, action, desc)
			}
			continue
		}
		_, combo := resolveKeys(m[1], "")
		add(combo, action, desc)
	}
	return out
}

// dispatcherAction classifies an hl.dsp.* expression into the short action label
// the conflict UI shows. It is the read side of genKeybind's action switch.
func dispatcherAction(d string) string {
	switch {
	case strings.Contains(d, "exec_cmd"):
		return "exec"
	case strings.Contains(d, "window.close"):
		return "close"
	case strings.Contains(d, "window.fullscreen"):
		return "fullscreen"
	case strings.Contains(d, "window.float"):
		return "togglefloating"
	case strings.Contains(d, "window.move"):
		return "move"
	case strings.Contains(d, "window.resize"):
		return "resize"
	case strings.Contains(d, "window.drag"):
		return "drag"
	case strings.Contains(d, "workspace"):
		return "workspace"
	case strings.Contains(d, "focus"):
		return "focus"
	case strings.Contains(d, "global"):
		return "global"
	case strings.Contains(d, "submap"):
		return "submap"
	}
	return "dispatch"
}
