{ pkgs, src }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "ryoku-desktop-data";
  version = "unstable";

  inherit src;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    cfg="$out/share/ryoku/config"

    mkdir -p \
      "$cfg" \
      "$out/bin" \
      "$out/share/applications" \
      "$out/share/icons/hicolor/scalable/apps" \
      "$out/share/ryoku"

    # ── Hyprland ───────────────────────────────────────────────

    mkdir -p "$cfg/hypr"
    cp -a ryoku/hyprland/. "$cfg/hypr/"

    # Qt QML modules are exposed through the system profile on NixOS.
    substituteInPlace "$cfg/hypr/modules/env.lua" \
      --replace-fail \
        'os.getenv("HOME") .. "/.local/lib/qt6/qml"' \
        'os.getenv("HOME") .. "/.local/lib/qt6/qml:/run/current-system/sw/lib/qt-6/qml"'

    # ----------------------------------------------------------
    # NixOS session bridge
    #
    # Ryoku's user services are managed by systemd.  Processes
    # started there do not automatically inherit the environment
    # of the Hyprland process launched by the display manager.
    #
    # Import the real compositor environment only after Hyprland
    # has created its Wayland socket, then start Ryoku's session
    # target.
    # ----------------------------------------------------------

    cat > "$cfg/hypr/ryoku-nix-session.sh" <<'SESSION'
#!/usr/bin/env bash
set -eu

systemctl --user import-environment \
  DISPLAY \
  WAYLAND_DISPLAY \
  HYPRLAND_INSTANCE_SIGNATURE \
  XDG_CURRENT_DESKTOP \
  XDG_SESSION_DESKTOP \
  XDG_SESSION_TYPE \
  XDG_RUNTIME_DIR \
  PATH

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    DISPLAY \
    WAYLAND_DISPLAY \
    HYPRLAND_INSTANCE_SIGNATURE \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_DESKTOP \
    XDG_SESSION_TYPE \
    XDG_RUNTIME_DIR \
    PATH
fi

systemctl --user start hyprland-session.target
SESSION

    chmod +x "$cfg/hypr/ryoku-nix-session.sh"

    # Append a tiny Nix-specific startup module to the materialized
    # Ryoku Hyprland configuration.
    #
    # Upstream's configuration is Lua, so locate its normal startup
    # module and add an exec there without replacing the desktop.
    if [ -f "$cfg/hypr/modules/autostart.lua" ]; then
      cat >> "$cfg/hypr/modules/autostart.lua" <<'LUA'

-- NixOS: export the live Hyprland environment to systemd before
-- starting Ryoku's user services.
hl.exec_cmd("~/.config/hypr/ryoku-nix-session.sh")
LUA
    else
      printf '%s
'         "Expected Ryoku Hyprland autostart module is missing." >&2
      exit 1
    fi

    # ── Main Quickshell shell ──────────────────────────────────

    mkdir -p "$cfg/quickshell"
    cp -a ryoku/shell/quickshell/. "$cfg/quickshell/"

    # ── Ryoku Settings / Hub ───────────────────────────────────

    mkdir -p "$cfg/quickshell/hub"
    cp -a ryoku/hub/quickshell/. "$cfg/quickshell/hub/"

    # ── First-party Ryoku Quickshell apps ──────────────────────

    for appdir in ryoku/apps/*/; do
      if [ -d "$appdir/quickshell" ]; then
        appname="$(basename "$appdir")"

        mkdir -p "$cfg/quickshell/$appname"
        cp -a "$appdir/quickshell/." "$cfg/quickshell/$appname/"

        icon="$appdir/quickshell/logo.svg"

        if [ ! -f "$icon" ]; then
          icon="$appdir/logo.svg"
        fi

        if [ ! -f "$icon" ]; then
          icon="ryoku/assets/brand/logo-mark.svg"
        fi

        install -Dm644 \
          "$icon" \
          "$out/share/icons/hicolor/scalable/apps/$appname.svg"
      fi

      if [ -d "$appdir/bin" ]; then
        for helper in "$appdir/bin/"*; do
          [ -f "$helper" ] || continue

          install -Dm755 \
            "$helper" \
            "$out/bin/$(basename "$helper")"
        done
      fi

      for desktop in "$appdir"*.desktop; do
        [ -f "$desktop" ] || continue

        install -Dm644 \
          "$desktop" \
          "$out/share/applications/$(basename "$desktop")"
      done
    done

    # ── Matugen / palette pipeline ─────────────────────────────

    mkdir -p "$cfg/matugen"
    cp -a ryoku/shell/matugen/. "$cfg/matugen/"

    # ── Qt / GTK appearance ────────────────────────────────────

    mkdir -p "$cfg/qt6ct"
    cp ryoku/shell/qt6ct/qt6ct.conf "$cfg/qt6ct/qt6ct.conf"

    mkdir -p "$cfg/gtk-3.0"
    cp ryoku/shell/gtk-3.0/settings.ini "$cfg/gtk-3.0/settings.ini"

    mkdir -p "$cfg/gtk-4.0"
    cp ryoku/shell/gtk-4.0/settings.ini "$cfg/gtk-4.0/settings.ini"

    # ── Application configs ────────────────────────────────────

    mkdir -p "$cfg/btop"
    cp ryoku/apps/btop/btop.conf "$cfg/btop/btop.conf"

    cp ryoku/apps/starship/starship.toml "$cfg/starship.toml"

    mkdir -p "$cfg/fastfetch"
    cp ryoku/apps/fastfetch/config.jsonc \
      "$cfg/fastfetch/config.jsonc"

    cp ryoku/assets/brand/fastfetch-emblem.png \
      "$cfg/fastfetch/fastfetch-emblem.png"

    mkdir -p "$cfg/kitty"
    cp -a ryoku/apps/kitty/. "$cfg/kitty/"

    # NixOS: do not force a particular login shell.
    # Kitty inherits the user's configured shell instead.
    substituteInPlace "$cfg/kitty/kitty.conf" \
      --replace-fail "shell /usr/bin/fish" ""

    # Ryoku's Fish configuration is part of the actual desktop package.
    mkdir -p "$cfg/fish/conf.d"
    cp ryoku/apps/fish/config.fish "$cfg/fish/config.fish"
    cp ryoku/apps/fish/conf.d/rashin.fish "$cfg/fish/conf.d/rashin.fish"

    mkdir -p "$cfg/wireplumber"
    cp -a ryoku/apps/wireplumber/. "$cfg/wireplumber/"

    mkdir -p "$cfg/yazi"
    cp ryoku/apps/yazi/yazi.toml "$cfg/yazi/yazi.toml"

    mkdir -p "$cfg/nvim"
    cp ryoku/apps/nvim/init.lua "$cfg/nvim/init.lua"
    cp ryoku/apps/nvim/.ryoku-lazyvim "$cfg/nvim/.ryoku-lazyvim"
    cp -a ryoku/apps/nvim/lua "$cfg/nvim/"

    mkdir -p "$cfg/pip"
    cp ryoku/apps/pip/pip.conf "$cfg/pip/pip.conf"

    cp ryoku/apps/chromium-flags.conf \
      "$cfg/chromium-flags.conf"

    mkdir -p "$cfg/hyprland-preview-share-picker"
    cp ryoku/apps/hyprland-preview-share-picker/config.yaml \
      "$cfg/hyprland-preview-share-picker/config.yaml"

    # ── User systemd session units ─────────────────────────────
    #
    # NixOS owns Ryoku's user services and targets declaratively
    # through nix/modules/ryoku.nix. Do not materialize upstream
    # units into ~/.config/systemd/user: user-local units override
    # the NixOS-managed definitions and upstream ExecStart paths
    # target /usr/bin.
    #
    # Upstream unit behaviour is mirrored by the NixOS module.

    # ── Helper binaries used by binds / shell ──────────────────

    for helper in ryoku/hyprland/scripts/ryoku-*; do
      [ -f "$helper" ] || continue

      install -Dm755 \
        "$helper" \
        "$out/bin/$(basename "$helper")"
    done

    install -Dm755 \
      ryoku/shell/quickshell/plugins/ryoku-plugins-place \
      "$out/bin/ryoku-plugins-place"

    install -Dm755 \
      ryoku/apps/fastfetch/ryoku-fastfetch \
      "$out/bin/ryoku-fastfetch"

    for helper in \
      ryoku/shell/bin/claude-usage \
      ryoku/shell/bin/codex-usage \
      ryoku/shell/bin/opencode-usage
    do
      install -Dm755 \
        "$helper" \
        "$out/bin/$(basename "$helper")"
    done

    # ── Ryotunes ───────────────────────────────────────────────

    install -Dm755 \
      ryoku/apps/ryotunes/bin/ryotunes \
      "$out/bin/ryotunes"

    install -Dm644 \
      ryoku/apps/ryotunes/ryotunes.desktop \
      "$out/share/applications/ryotunes.desktop"

    install -Dm644 \
      ryoku/apps/ryotunes/ryotunes.svg \
      "$out/share/icons/hicolor/scalable/apps/ryotunes.svg"

    # ── Lockscreen ─────────────────────────────────────────────

    mkdir -p "$out/share/ryoku/lockscreen"

    cp -a \
      ryoku/lockscreen/qylock \
      "$out/share/ryoku/lockscreen/qylock"

    install -Dm755 \
      ryoku/lockscreen/install-qylock \
      "$out/share/ryoku/lockscreen/install-qylock"

    # ── Desktop integration ────────────────────────────────────

    install -Dm644 \
      ryoku/apps/nautilus/ryoku-stash-menu.py \
      "$out/share/ryoku/nautilus/ryoku-stash-menu.py"

    install -Dm644 \
      ryoku/apps/spicetify/ryoku-canvas.js \
      "$out/share/ryoku/spicetify/ryoku-canvas.js"

    # ── Browser integration ────────────────────────────────────

    mkdir -p "$out/share/ryoku/browser"

    (
      cd ryoku/browser
      sh ./build.sh
    )

    cp -a ryoku/browser/. "$out/share/ryoku/browser/"

    # ── Wallpapers ─────────────────────────────────────────────

    mkdir -p "$out/share/ryoku/wallpapers"

    if [ -d ryoku/assets/wallpapers ]; then
      cp -a \
        ryoku/assets/wallpapers/. \
        "$out/share/ryoku/wallpapers/"
    fi

    # ── Ryoku decor artwork ────────────────────────────────────

    mkdir -p "$out/share/ryoku/ryodecors"

    cp -a \
      ryoku/assets/ryodecors/. \
      "$out/share/ryoku/ryodecors/"

    # ── Brand assets ───────────────────────────────────────────

    mkdir -p "$out/share/ryoku/brand"

    cp -a \
      ryoku/assets/brand/. \
      "$out/share/ryoku/brand/"

    chmod -R u=rwX,go=rX "$out/share"

    runHook postInstall
  '';
  meta = {
    description = "Ryoku desktop configuration, assets, applications and integration data";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };

}
