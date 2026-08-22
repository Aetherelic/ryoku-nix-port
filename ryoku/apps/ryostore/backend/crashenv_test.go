package main

import (
	"os/exec"
	"strings"
	"testing"
)

// The scrub has to reach the actual process environment, not a copy, because the
// point is that the qs children openConfig starts inherit a clean environment. A
// real child (env) is the only honest proof: it must not see the five crash
// variables and must still see everything else we set.
func TestCrashEnvScrub(t *testing.T) {
	crashVars := []string{
		"__QUICKSHELL_CRASH_INFO_FD",
		"__QUICKSHELL_CRASH_DUMP_PID",
		"__QUICKSHELL_CRASH_DUMP_FD",
		"__QUICKSHELL_CRASH_LOG_FD",
		"__QUICKSHELL_CRASH_SIGNAL",
	}
	for _, name := range crashVars {
		t.Setenv(name, "7")
	}
	t.Setenv("RYOSTORE_CRASHENV_KEEP", "keep-me")

	scrubQuickshellCrashEnv()

	out, err := exec.Command("env").Output()
	if err != nil {
		t.Fatalf("env: %v", err)
	}
	child := map[string]string{}
	for _, line := range strings.Split(string(out), "\n") {
		if k, v, ok := strings.Cut(line, "="); ok {
			child[k] = v
		}
	}

	for _, name := range crashVars {
		if v, ok := child[name]; ok {
			t.Errorf("child still sees %s=%q; the scrub did not reach the environment", name, v)
		}
	}
	if child["RYOSTORE_CRASHENV_KEEP"] != "keep-me" {
		t.Errorf("child lost RYOSTORE_CRASHENV_KEEP=%q, want keep-me; the scrub was too broad", child["RYOSTORE_CRASHENV_KEEP"])
	}
}
