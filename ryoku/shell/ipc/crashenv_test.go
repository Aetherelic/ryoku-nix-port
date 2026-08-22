package main

import (
	"os/exec"
	"strings"
	"testing"
)

// TestCrashEnvScrub proves scrubQuickshellCrashEnv reaches real children: a
// process we exec after the scrub must not inherit any crash var, while an
// unrelated variable set alongside them survives untouched.
func TestCrashEnvScrub(t *testing.T) {
	crashVars := []string{
		"__QUICKSHELL_CRASH_INFO_FD",
		"__QUICKSHELL_CRASH_DUMP_PID",
		"__QUICKSHELL_CRASH_DUMP_FD",
		"__QUICKSHELL_CRASH_LOG_FD",
		"__QUICKSHELL_CRASH_SIGNAL",
	}
	for _, name := range crashVars {
		t.Setenv(name, "42")
	}
	t.Setenv("RYOKU_CRASHENV_KEEP", "keep-me")

	scrubQuickshellCrashEnv()

	// A child inherits os.Environ() by default, so its view of the environment
	// is exactly what a spawned qs would get.
	out, err := exec.Command("env").Output()
	if err != nil {
		t.Fatalf("env: %v", err)
	}
	child := make(map[string]string)
	for _, line := range strings.Split(string(out), "\n") {
		if k, v, ok := strings.Cut(line, "="); ok {
			child[k] = v
		}
	}

	for _, name := range crashVars {
		if v, ok := child[name]; ok {
			t.Errorf("child inherited %s=%q, want it unset", name, v)
		}
	}
	if got := child["RYOKU_CRASHENV_KEEP"]; got != "keep-me" {
		t.Errorf("unrelated var = %q, want %q", got, "keep-me")
	}
}
