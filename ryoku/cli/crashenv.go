package main

import "os"

// internal/doctor/reconcile_shell_load.go runs `qs -c shell` and waits for it,
// and ryoku is often run from a terminal the desktop opened. Inheriting
// Quickshell's crash-recovery handle turns that check into a second desktop that
// never exits, so `ryoku doctor` would hang while a duplicate bar and dock draw
// over the first. Upstream reads __QUICKSHELL_CRASH_INFO_FD before it parses any
// argument (checkCrashRelaunch, src/launch/main.cpp), so clearing it from our own
// environment is what makes every qs child we start honour -c <config>.
func scrubQuickshellCrashEnv() {
	for _, name := range []string{
		"__QUICKSHELL_CRASH_INFO_FD",
		"__QUICKSHELL_CRASH_DUMP_PID",
		"__QUICKSHELL_CRASH_DUMP_FD",
		"__QUICKSHELL_CRASH_LOG_FD",
		"__QUICKSHELL_CRASH_SIGNAL",
	} {
		os.Unsetenv(name)
	}
}
