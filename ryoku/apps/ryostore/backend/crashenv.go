package main

import "os"

// openConfig in routing.go runs `flock ... qs -c <config>` and then
// `qs -c <config> ipc call nav open <section>`, and ryostore is launched from the
// Hub and the desktop. An inherited Quickshell crash-recovery handle makes both
// of those relaunch the desktop config instead of the store surface. Upstream
// reads __QUICKSHELL_CRASH_INFO_FD before it parses any argument
// (checkCrashRelaunch, src/launch/main.cpp), so clearing it from our own
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
