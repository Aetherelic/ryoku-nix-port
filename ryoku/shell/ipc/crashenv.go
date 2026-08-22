package main

import "os"

// ryoku-shell runs qs for the desktop, the Hub and every surface, and is itself
// launched from the desktop, so it can inherit the desktop's Quickshell
// crash-recovery handle. Left in place, `qs -c hub` relaunches the desktop config
// instead of the Hub. Upstream reads __QUICKSHELL_CRASH_INFO_FD before it parses
// any argument (checkCrashRelaunch, src/launch/main.cpp), so clearing it from our
// own environment is what makes every qs child honour -c <config>, and scrubbing
// once at startup means no call site has to remember.
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
