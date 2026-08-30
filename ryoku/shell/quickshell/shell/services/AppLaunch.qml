pragma Singleton

import Quickshell
import Ryoku.Ui.Singletons

// One launcher for XDG desktop entries. Quickshell parses Terminal=true into
// runInTerminal but spawns no terminal for it, so a TUI (btop, yazi, nvim) got no
// tty and died at once; ryoku-app owns which terminal the user picked.
//
// Launching goes through Spawn rather than DesktopEntry.execute(): execute()
// hands the child the desktop's whole environment, and a Quickshell app that
// inherits the crash handle in it relaunches the desktop instead of starting.
Singleton {
    id: root

    // NixOS runs the resident shell as a systemd user service. Applications
    // launched directly by Quickshell would otherwise inherit that service's
    // cgroup and be killed or leaked when the shell restarts.
    //
    // Put user applications in transient app.slice scopes on NixOS. Arch keeps
    // the existing direct Spawn behaviour unchanged.
    readonly property bool isolateUserApps:
        (Quickshell.env("RYOKU_NIX_SYSTEM_BRIDGE") || "") === "1"

    readonly property string systemdRun:
        Quickshell.env("RYOKU_SYSTEMD_RUN") || "systemd-run"

    function spawnUserApp(argv, workingDirectory) {
        if (!argv || argv.length === 0)
            return;

        var command = [];

        if (root.isolateUserApps) {
            command = [
                root.systemdRun,
                "--user",
                "--scope",
                "--quiet",
                "--collect",
                "--slice=app.slice",
                "--"
            ];
        }

        for (let i = 0; i < argv.length; i++)
            command.push(String(argv[i]));

        Spawn.run(command, workingDirectory || "");
    }

    // run(entry) launches the entry; run(entry, action) launches one of its
    // actions, which inherit Terminal= from the entry that declares them.
    function run(entry, action) {
        const target = action || entry;
        if (!target)
            return;
        const argv = entry && entry.runInTerminal ? (target.command || []) : [];
        if (argv.length === 0) {
            root.spawnUserApp(
                target.command,
                entry ? entry.workingDirectory : ""
            );
            return;
        }
        const command = ["ryoku-app", "terminal", "--"];
        for (let i = 0; i < argv.length; i++)
            command.push(String(argv[i]));
        root.spawnUserApp(command, "");
    }
}
