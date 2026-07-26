package main

import "testing"

// TestSelectionFromReply covers every reply form the helper forwards to the
// portal: each selection string is printed verbatim, a cancel is the empty
// string, and a daemon-side failure surfaces as an error (non-zero exit).
func TestSelectionFromReply(t *testing.T) {
	ok := []struct {
		name, line, want string
	}{
		{"screen", `{"ok":true,"result":"[SELECTION]/screen:DP-1"}`, "[SELECTION]/screen:DP-1"},
		{"region", `{"ok":true,"result":"[SELECTION]/region:DP-1@100,200,640,480"}`, "[SELECTION]/region:DP-1@100,200,640,480"},
		{"window", `{"ok":true,"result":"[SELECTION]/window:0x1"}`, "[SELECTION]/window:0x1"},
		{"cancel empty result", `{"ok":true,"result":""}`, ""},
		{"cancel absent result", `{"ok":true}`, ""},
	}
	for _, c := range ok {
		t.Run(c.name, func(t *testing.T) {
			got, err := selectionFromReply(c.line)
			if err != nil {
				t.Fatalf("selectionFromReply(%q) error: %v", c.line, err)
			}
			if got != c.want {
				t.Errorf("selectionFromReply(%q) = %q, want %q", c.line, got, c.want)
			}
		})
	}

	bad := []struct{ name, line string }{
		{"daemon error", `{"ok":false,"error":"unknown method"}`},
		{"malformed", `not json`},
	}
	for _, c := range bad {
		t.Run(c.name, func(t *testing.T) {
			if _, err := selectionFromReply(c.line); err == nil {
				t.Errorf("selectionFromReply(%q) = nil error, want failure", c.line)
			}
		})
	}
}
