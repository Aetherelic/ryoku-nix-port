{ pkgs, ryoku }:

pkgs.writeShellApplication {
  name = "ryoku-materialize";

  runtimeInputs = with pkgs; [
    coreutils
    findutils
    systemd
  ];

  text = ''
    base="${ryoku.desktopData}/share/ryoku/config"
    qml="${ryoku.qml}/lib/qt-6/qml"

    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
    user_units="$config_home/systemd/user"
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/nix"
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="$state/backups/$stamp"

    mkdir -p "$state"

    # ----------------------------------------------------------
    # First deployment backup
    #
    # Derive the backup set from the packaged config itself.
    # This keeps the backup complete when upstream adds another
    # application config instead of maintaining a second list here.
    # ----------------------------------------------------------

    if [ ! -e "$state/initial-backup-complete" ]; then
      mkdir -p "$backup/config"

      while IFS= read -r -d "" packaged; do
        name="''${packaged##*/}"
        current="$config_home/$name"

        if [ -e "$current" ] || [ -L "$current" ]; then
          cp -a -- "$current" "$backup/config/"
        fi
      done < <(
        find "$base" \
          -mindepth 1 \
          -maxdepth 1 \
          -print0
      )

      # Ryoku also owns these user-local QML module names. They live
      # outside XDG_CONFIG_HOME, so preserve a previous deployment
      # before replacing the modules with Nix-store links.
      current_qml="$HOME/.local/lib/qt6/qml/Ryoku"

      if [ -e "$current_qml" ] || [ -L "$current_qml" ]; then
        mkdir -p "$backup/local-qml"
        cp -a -- "$current_qml" "$backup/local-qml/"
      fi

      # Preserve any existing Ryoku user units before NixOS takes
      # ownership of these names.
      for unit in \
        hyprland-session.target \
        ryoku-shell.service \
        ryoku-rashin.service \
        ryoku-ai-usage.service \
        ryoku-ai-usage.timer
      do
        current="$user_units/$unit"

        if [ -e "$current" ] || [ -L "$current" ]; then
          mkdir -p "$backup/systemd-user"
          cp -a -- "$current" "$backup/systemd-user/"
        fi
      done

      printf '%s\n' "$backup" > "$state/initial-backup-path"
      touch "$state/initial-backup-complete"
    fi

    # ----------------------------------------------------------
    # Upstream materialization
    # ----------------------------------------------------------

    export RYOKU_CONFIG_BASE="$base"

    ${ryoku.cli}/bin/ryoku materialize

    # Seeds copied out of the Nix store need to remain writable.
    for file in \
      hypr/monitors.lua \
      hypr/gpu.lua \
      hypr/keyboard.lua \
      hypr/user.lua \
      fastfetch/config.jsonc \
      kitty/current-theme.conf
    do
      [ -f "$config_home/$file" ] && chmod u+w "$config_home/$file"
    done

    # ----------------------------------------------------------
    # QML modules
    #
    # Upstream env.lua expects ~/.local/lib/qt6/qml for a
    # non-/usr development deployment.
    # ----------------------------------------------------------

    user_qml="$HOME/.local/lib/qt6/qml/Ryoku"

    mkdir -p "$user_qml"

    for module in Ui PluginKit FrameBars Blobs; do
      rm -rf -- "''${user_qml:?}/$module"

      ln -s \
        "$qml/Ryoku/$module" \
        "$user_qml/$module"
    done

    # Hyprland's optional plugins are immutable Nix packages, but the
    # upstream Hub already knows how to discover/load ~/.local plugin files.
    # Materialize stable user-facing symlinks instead of teaching the Hub Nix
    # store paths or writing into /usr/lib.
    plugin_dir="$HOME/.local/lib/hyprland/plugins"
    mkdir -p "$plugin_dir"

    for plugin in dynamic-cursors hyprbars hyprfocus hyprglass imgborders; do
      rm -f -- "$plugin_dir/$plugin.so"
      ln -s \
        "${ryoku.hyprPlugins}/lib/hyprland/plugins/$plugin.so" \
        "$plugin_dir/$plugin.so"
    done

    # ----------------------------------------------------------
    # NixOS owns Ryoku's systemd user units declaratively.
    #
    # Remove legacy units left by an older materialization or an
    # existing Arch Ryoku deployment. User-local units otherwise
    # override the NixOS-managed definitions.
    # ----------------------------------------------------------

    rm -f -- \
      "$user_units/hyprland-session.target" \
      "$user_units/ryoku-shell.service" \
      "$user_units/ryoku-rashin.service" \
      "$user_units/ryoku-ai-usage.service" \
      "$user_units/ryoku-ai-usage.timer"

    systemctl --user daemon-reload 2>/dev/null || true

    # ----------------------------------------------------------
    # Seed visible assets without replacing user files
    # ----------------------------------------------------------

    data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"

    mkdir -p \
      "$HOME/Pictures/Wallpapers" \
      "$HOME/Pictures/ryodecors" \
      "$data_home/ryoku/assets/brand"

    if [ -d "${ryoku.desktopData}/share/ryoku/wallpapers" ]; then
      cp -n \
        "${ryoku.desktopData}/share/ryoku/wallpapers/"* \
        "$HOME/Pictures/Wallpapers/" \
        2>/dev/null || true
    fi

    if [ -d "${ryoku.desktopData}/share/ryoku/ryodecors" ]; then
      cp -n \
        "${ryoku.desktopData}/share/ryoku/ryodecors/"* \
        "$HOME/Pictures/ryodecors/" \
        2>/dev/null || true
    fi

    if [ -d "${ryoku.desktopData}/share/ryoku/brand" ]; then
      cp -n \
        "${ryoku.desktopData}/share/ryoku/brand/"* \
        "$data_home/ryoku/assets/brand/" \
        2>/dev/null || true
    fi

    # User-space equivalents for integrations normally installed under /usr.
    ryoku_data="$data_home/ryoku"

    mkdir -p \
      "$data_home/nautilus-python/extensions" \
      "$ryoku_data/spicetify"

    ln -sfn \
      "${ryoku.desktopData}/share/ryoku/nautilus/ryoku-stash-menu.py" \
      "$data_home/nautilus-python/extensions/ryoku-stash-menu.py"

    if [ ! -e "$ryoku_data/browser" ] || [ -L "$ryoku_data/browser" ]; then
      ln -sfnT \
        "${ryoku.desktopData}/share/ryoku/browser" \
        "$ryoku_data/browser"
    fi

    ln -sfn \
      "${ryoku.desktopData}/share/ryoku/spicetify/ryoku-canvas.js" \
      "$ryoku_data/spicetify/ryoku-canvas.js"

    printf '\n'
    printf 'Ryoku desktop materialized successfully.\n'

    if [ -f "$state/initial-backup-path" ]; then
      printf 'Original config backup: %s\n' \
        "$(cat "$state/initial-backup-path")"
    fi

    printf '\nLog out and start Hyprland to enter Ryoku.\n'
  '';
}
