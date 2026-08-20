pragma Singleton

import Quickshell

// One launcher for XDG desktop entries. Quickshell parses Terminal=true into
// runInTerminal but spawns no terminal for it, so a TUI (btop, yazi, nvim) got no
// tty and died at once; ryoku-app owns which terminal the user picked.
Singleton {
    id: root

    // run(entry) launches the entry; run(entry, action) launches one of its
    // actions, which inherit Terminal= from the entry that declares them.
    function run(entry, action) {
        const target = action || entry;
        if (!target)
            return;
        const argv = entry && entry.runInTerminal ? (target.command || []) : [];
        if (argv.length === 0) {
            target.execute();
            return;
        }
        const command = ["ryoku-app", "terminal", "--"];
        for (let i = 0; i < argv.length; i++)
            command.push(String(argv[i]));
        Quickshell.execDetached(command);
    }
}
