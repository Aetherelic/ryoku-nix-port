hl.on("hyprland.start", function()
    -- Start the GNOME keyring's secrets + pkcs11 agents before anything that
    -- might ask for a stored secret. Idempotent: if PAM already started it at
    -- login (unlock-on-login mode), this just re-prints its env and exits.
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")
    -- Folder icons follow the wallpaper accent: ryoku-cmd-folders builds a small
    -- Papirus-Dark overlay under ~/.local/share/icons tinted to the palette and
    -- selects it. Rebuilt on every palette change by the shell's matugen hook.
    hl.exec_cmd("command -v ryoku-cmd-folders >/dev/null 2>&1 && ryoku-cmd-folders")
    -- ONE chained command: exec is fire-and-forget, so as separate lines the
    -- shell start races the env import, and losing means
    -- ConditionEnvironment=WAYLAND_DISPLAY skips the unit (a black desktop).
    -- --all, not a name list: a keybind-launched app is Hyprland's child and
    -- sees every hl.env() name, a systemd or D-Bus launched one sees only what
    -- is pushed here, and a hand-kept list drifts the moment env.lua, the Hub,
    -- or user.lua adds one.
    -- Portals restart last, once the desktop is up: they are only
    -- PartOf=graphical-session.target and nothing stops that target, so a
    -- previous session's frontend survives and every ScreenCast request it
    -- proxies times out instead of reaching the backend.
    hl.exec_cmd("dbus-update-activation-environment --systemd --all; systemctl --user start hyprland-session.target; systemctl --user start ryoku-shell; systemctl --user try-restart xdg-desktop-portal.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service")
    -- Polkit authentication is answered by the shell's own agent (the island
    -- that matches the rest of the desktop), so the stock Qt agent must not
    -- take the session's single agent slot. Stopping it is idempotent and
    -- harmless when it was never started.
    hl.exec_cmd("systemctl --user stop hyprpolkitagent 2>/dev/null || true")
    hl.exec_cmd("command -v ryoku-monitor >/dev/null 2>&1 && ryoku-monitor autoscale")
    -- Per-device Bluetooth codec memory. WirePlumber restores a device's PROFILE
    -- across reconnects but not its A2DP codec, so a user who picked one has to
    -- pick it again every single time the buds come back. `watch` reconciles on
    -- every card event and is a no-op for anyone who never chose a codec, so it
    -- costs a subscription and nothing else.
    hl.exec_cmd("command -v ryoku-bt-audio >/dev/null 2>&1 && ryoku-bt-audio watch")
    -- Keyring default: no app ever prompts for a keyring password out of the box.
    -- `keyring init` records the mode once and seeds a blank passwordless default
    -- keyring for never-ask (idempotent; a no-op once a mode is chosen). Best
    -- effort: an old ryoku without the subcommand just fails silently here.
    hl.exec_cmd("command -v ryoku >/dev/null 2>&1 && ryoku keyring init")
    hl.exec_cmd("command -v ryoku-gpu >/dev/null 2>&1 && ryoku-gpu persist")
    hl.exec_cmd("command -v ryoku-idle >/dev/null 2>&1 && ryoku-idle start")
    hl.exec_cmd("command -v ryoku-clamshell >/dev/null 2>&1 && ryoku-clamshell daemon")
    -- Power knobs the kernel forgets across a reboot: the battery charge ceiling
    -- and the PCIe link policy are plain sysfs values, so a stored choice has to
    -- be pushed back at login or it silently lapses. A no-op with no
    -- ~/.config/ryoku/power.json, and on a desktop or a box without the knobs.
    hl.exec_cmd("command -v ryoku-power >/dev/null 2>&1 && ryoku-power apply")
    -- Device lighting: push the stored look back at the keyboards and mice the
    -- user put under Ryoku's control (Hub > Appearance > Lighting). A no-op, and
    -- no OpenRGB at all, until lighting is on with a device adopted.
    hl.exec_cmd("command -v ryoku-hub >/dev/null 2>&1 && ryoku-hub lighting apply")
    hl.exec_cmd("command -v ryoku-mic >/dev/null 2>&1 && ryoku-mic")
    -- Booted into a btrfs snapshot from the Limine menu: offer the one-click
    -- restore. limine-snapper-sync ships this as an XDG autostart entry, which
    -- Hyprland never runs (no autostart manager), so start it here; on a normal
    -- boot it detects no snapshot and exits silently.
    hl.exec_cmd("command -v limine-snapper-restore >/dev/null 2>&1 && limine-snapper-restore --notify")
    -- Voxtype dictation: `ryoku-hub voxtype ensure` seeds a default config with
    -- the built-in hotkey off (the shell owns Super+` and the mic wave), installs
    -- the user service once, and starts it unless you turned dictation off in the
    -- Hub. The shell then drives it with `voxtype record` on the Super+` tap.
    hl.exec_cmd("command -v voxtype >/dev/null 2>&1 && command -v ryoku-hub >/dev/null 2>&1 && ryoku-hub voxtype ensure >/dev/null 2>&1")
    -- AI UI translation: seed ~/.config/ryoku/i18n-llm.json (empty key) so the
    -- file exists for the user to paste an API key into; idempotent, a no-op if
    -- present. The Hub's Language > "Generate with AI" then reads it.
    hl.exec_cmd("command -v ryoku-i18n >/dev/null 2>&1 && ryoku-i18n ensure >/dev/null 2>&1")
    -- Welcome walkthrough: show the guided tour once per tour VERSION. A fresh
    -- box (no flag) sees it; a box that saw an older tour (a bare flag or a lower
    -- version) sees the refreshed tour once more on update; a box already on this
    -- version is left alone. The flag lives in state (not config), so it needs no
    -- doctor reconciler. The seen-check lives in Lua because Hyprland's exec reads
    -- a leading [...] as its window-rules prefix, and because Lua can compare the
    -- stored version. The flock guards a double fire, and the version is written
    -- only if qs actually ran the tour (`&&`), so a first-boot launch failure
    -- retries next login instead of marking it seen. exec is async, so the
    -- blocking `qs` never holds up autostart. Bump welcome_version when the tour
    -- changes materially (beta 18 = 18).
    local welcome_state = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/ryoku"
    local welcome_version = 18
    local seen_file = io.open(welcome_state .. "/welcome-seen", "r")
    local seen_version = 0
    if seen_file then
        seen_version = tonumber((seen_file:read("*l") or "")) or 0
        seen_file:close()
    end
    if seen_version < welcome_version then
        hl.exec_cmd("flock -n \"${XDG_RUNTIME_DIR:-/tmp}/ryoku-welcome.lock\" qs -c welcome && mkdir -p '" .. welcome_state .. "' && printf '" .. welcome_version .. "' > '" .. welcome_state .. "/welcome-seen'")
    end
end)
