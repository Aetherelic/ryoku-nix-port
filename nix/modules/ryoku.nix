{ self }:

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ryoku;

  system = pkgs.stdenv.hostPlatform.system;

  ryokuPkgs = self.packages.${system};

  ryokuShell = ryokuPkgs.ryoku-shell;
  ryokuRashin = ryokuPkgs.ryoku-rashin;
  ryokuBundle = ryokuPkgs.ryoku-bundle;
  ryokuHelpers = ryokuPkgs.ryoku-helpers;
  ryokuSystemBridge = ryokuPkgs.ryoku-nixos-system-bridge;
  ryokuDesktopData = ryokuPkgs.ryoku-desktop-data;

  # Hyprland plugins are ABI-sensitive, so the compositor, portal and
  # plugin bundle must all come from Ryoku's own locked package set.
  ryokuHyprland = ryokuPkgs.ryoku-hyprland;
  ryokuHyprlandPortal = ryokuPkgs.ryoku-xdg-desktop-portal-hyprland;
  ryokuHyprPlugins = ryokuPkgs.ryoku-hypr-plugins;
  ryokuCursorMaterial = ryokuPkgs.ryoku-cursor-material;
  ryokuMapleMonoNF = ryokuPkgs.ryoku-maple-mono-nf;
  materializer = ryokuPkgs.ryoku-materialize;

  # ───────────────────────────────────────────────────────────
  # Ryoku qylock
  #
  # Upstream's installer writes directly into /usr/share and
  # ~/.local/share. On NixOS the SDDM half is immutable while
  # the in-session lock is materialized into the user's home.
  # ───────────────────────────────────────────────────────────

  qylockMaterializer = pkgs.writeShellScript "ryoku-qylock-materialize" ''
    set -euo pipefail

    source_root="${ryokuDesktopData}/share/ryoku/lockscreen/qylock"

    data_home="$HOME/.local/share"
    config_home="$HOME/.config"

    lock_dir="$data_home/quickshell-lockscreen"
    themes_dir="$data_home/qylock/themes"

    if [ ! -f "$source_root/quickshell-lockscreen/lock_shell.qml" ]; then
      echo "ryoku-qylock-materialize: lockscreen payload is missing" >&2
      exit 1
    fi

    if [ ! -f "$source_root/themes/clockwork/orbital/Main.qml" ]; then
      echo "ryoku-qylock-materialize: fallback theme is missing" >&2
      exit 1
    fi

    install -d \
      "$data_home" \
      "$themes_dir" \
      "$themes_dir/clockwork" \
      "$config_home/qylock"

    # Ryoku owns the lock runtime itself. Refresh it atomically enough for
    # normal generation switches while keeping user-installed themes separate.
    tmp="$(mktemp -d "$data_home/.quickshell-lockscreen.XXXXXX")"
    trap 'rm -rf "$tmp"' EXIT

    cp -a "$source_root/quickshell-lockscreen/." "$tmp/"
    chmod -R u+w "$tmp"
    chmod 700 "$tmp/lock.sh"

    # NixOS does not ship Arch's pam_fprintd_grosshack module.
    # Replace qylock's bundled Arch-oriented PAM stack with a
    # password-only stack using absolute modules from Nix's PAM package.
    pam_dir="$tmp/assets/pam"
    mkdir -p "$pam_dir"

    cat > "$pam_dir/ryoku-lock" <<'EOF'
#%PAM-1.0
#
# Ryoku qylock — NixOS PAM stack
#
# Fingerprint grosshack support is intentionally omitted until it has
# a proper Nix package. Password authentication remains fully native.

auth       required  ${config.security.pam.package}/lib/security/pam_unix.so try_first_pass
auth       optional  ${config.security.pam.package}/lib/security/pam_env.so
account    required  ${config.security.pam.package}/lib/security/pam_unix.so
password   required  ${config.security.pam.package}/lib/security/pam_deny.so
session    required  ${config.security.pam.package}/lib/security/pam_unix.so
EOF

    chmod 600 "$pam_dir/ryoku-lock"


    # Linux-PAM also probes the fallback "other" service when using a
    # custom config directory. Provide a deny-by-default fallback so the
    # lock journal stays clean and unknown PAM services fail securely.
    cat > "$pam_dir/other" <<'EOF'
#%PAM-1.0
auth       required  ${config.security.pam.package}/lib/security/pam_deny.so
account    required  ${config.security.pam.package}/lib/security/pam_deny.so
password   required  ${config.security.pam.package}/lib/security/pam_deny.so
session    required  ${config.security.pam.package}/lib/security/pam_deny.so
EOF

    chmod 600 "$pam_dir/other"

    rm -rf "$lock_dir"
    mv "$tmp" "$lock_dir"
    trap - EXIT

    # Refresh only Ryoku's built-in fallback theme. RyoStore/user themes survive.
    rm -rf "$themes_dir/clockwork/orbital"
    cp -a \
      "$source_root/themes/clockwork/orbital" \
      "$themes_dir/clockwork/orbital"

    chmod -R u+w "$themes_dir/clockwork/orbital"

    rm -rf "$lock_dir/themes_link"
    ln -s "$themes_dir" "$lock_dir/themes_link"

    # Seed the default once. Never overwrite a user's selected skin.
    if [ ! -s "$config_home/qylock/theme" ]; then
      printf '%s\n' 'clockwork/orbital' > "$config_home/qylock/theme"
      chmod 600 "$config_home/qylock/theme"
    fi
  '';

  # SDDM itself remains declaratively configured as the fixed "ryoku" theme.
  # Only the selected theme payload is mutable.
  ryokuSddmStateDir = "/var/lib/ryoku/sddm-theme";

  ryokuSddmThemeApply = pkgs.writeShellScriptBin "ryoku-sddm-theme-apply" ''
    set -euo pipefail

    slug="''${1:-}"

    case "$slug" in
      ""|/*|*".."*)
        printf 'ryoku-sddm-theme-apply: invalid skin slug: %s\n' "$slug" >&2
        exit 2
        ;;
    esac

    uid="''${PKEXEC_UID:-}"
    if [ -z "$uid" ]; then
      uid="''${SUDO_UID:-}"
    fi

    case "$uid" in
      ""|*[!0-9]*)
        printf 'ryoku-sddm-theme-apply: cannot determine invoking user\n' >&2
        exit 2
        ;;
    esac

    if [ "$uid" = "0" ]; then
      printf 'ryoku-sddm-theme-apply: refusing root as the theme owner\n' >&2
      exit 2
    fi

    passwd_line="$(${pkgs.glibc.bin}/bin/getent passwd "$uid" || true)"
    home="$(printf '%s\n' "$passwd_line" | ${pkgs.coreutils}/bin/cut -d: -f6)"

    if [ -z "$home" ]; then
      printf 'ryoku-sddm-theme-apply: cannot resolve home for uid %s\n' "$uid" >&2
      exit 2
    fi

    themes_root="$home/.local/share/qylock/themes"
    src="$themes_root/$slug"

    themes_real="$(${pkgs.coreutils}/bin/readlink -f -- "$themes_root" 2>/dev/null || true)"
    src_real="$(${pkgs.coreutils}/bin/readlink -f -- "$src" 2>/dev/null || true)"

    if [ -z "$themes_real" ] || [ -z "$src_real" ]; then
      printf 'ryoku-sddm-theme-apply: skin is not installed: %s\n' "$slug" >&2
      exit 1
    fi

    case "$src_real" in
      "$themes_real"/*)
        ;;
      *)
        printf 'ryoku-sddm-theme-apply: skin escaped the qylock theme root\n' >&2
        exit 2
        ;;
    esac

    if [ ! -f "$src_real/Main.qml" ]; then
      printf 'ryoku-sddm-theme-apply: skin has no Main.qml: %s\n' "$slug" >&2
      exit 1
    fi

    ${pkgs.coreutils}/bin/install -d -m 0755 /var/lib/ryoku

    tmp="$(${pkgs.coreutils}/bin/mktemp -d /var/lib/ryoku/.sddm-theme.XXXXXX)"
    trap '${pkgs.coreutils}/bin/rm -rf "$tmp"' EXIT

    ${pkgs.coreutils}/bin/cp \
      -a \
      --no-preserve=ownership \
      "$src_real/." \
      "$tmp/"

    ${pkgs.coreutils}/bin/chown -R root:root "$tmp"
    ${pkgs.coreutils}/bin/chmod -R a+rX "$tmp"

    ${pkgs.coreutils}/bin/rm -rf /var/lib/ryoku/sddm-theme
    ${pkgs.coreutils}/bin/mv "$tmp" /var/lib/ryoku/sddm-theme

    trap - EXIT

    printf 'Ryoku SDDM theme -> %s\n' "$slug"
  '';

  # The path SDDM sees is immutable, while its payload lives in /var/lib.
  # This keeps services.displayManager.sddm.theme permanently set to "ryoku"
  # and lets Hub change the visual theme without rewriting NixOS configuration.
  ryokuSddmTheme = pkgs.runCommand "ryoku-sddm-theme" { } ''
    mkdir -p "$out/share/sddm/themes"
    ln -s "${ryokuSddmStateDir}" "$out/share/sddm/themes/ryoku"
  '';


  ryokuUdevRules = pkgs.runCommand "ryoku-udev-rules" {
    nativeBuildInputs = [
      pkgs.makeWrapper
    ];
  } ''
    rules="$out/lib/udev/rules.d"
    libexec="$out/libexec"

    mkdir -p "$rules" "$libexec"

    install -Dm755 \
      ${self}/system/hardware/input/ryoku-hw-qmk \
      "$libexec/ryoku-hw-qmk"

    patchShebangs "$libexec/ryoku-hw-qmk"

    wrapProgram "$libexec/ryoku-hw-qmk" \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
      ]}

    install -Dm644 \
      ${self}/system/hardware/ddc/60-ryoku-i2c.rules \
      "$rules/60-ryoku-i2c.rules"

    install -Dm644 \
      ${self}/system/hardware/input/62-ryoku-qmk-hid.rules \
      "$rules/62-ryoku-qmk-hid.rules"

    install -Dm644 \
      ${self}/system/hardware/audio/70-ryoku-maono.rules \
      "$rules/70-ryoku-maono.rules"

    install -Dm644 \
      ${self}/system/hardware/input/72-ryoku-keyboard-uaccess.rules \
      "$rules/72-ryoku-keyboard-uaccess.rules"

    install -Dm644 \
      ${self}/system/hardware/display/90-ryoku-backlight.rules \
      "$rules/90-ryoku-backlight.rules"

    install -Dm644 \
      ${self}/system/hardware/gpu/90-ryoku-gpu.rules \
      "$rules/90-ryoku-gpu.rules"

    substituteInPlace "$rules/62-ryoku-qmk-hid.rules" \
      --replace-fail \
        "/usr/bin/ryoku-hw-qmk" \
        "$libexec/ryoku-hw-qmk"

    substituteInPlace "$rules/90-ryoku-backlight.rules" \
      --replace-fail \
        "/usr/bin/chgrp" \
        "${pkgs.coreutils}/bin/chgrp" \
      --replace-fail \
        "/usr/bin/chmod" \
        "${pkgs.coreutils}/bin/chmod"

    substituteInPlace "$rules/90-ryoku-gpu.rules" \
      --replace-fail \
        "/bin/sh" \
        "${pkgs.runtimeShell}" \
      --replace-fail \
        "| sed " \
        "| ${pkgs.gnused}/bin/sed " \
      --replace-fail \
        "| tr " \
        "| ${pkgs.coreutils}/bin/tr "
  '';

  qmlRoot = "${ryokuPkgs.ryoku-qml}/lib/qt-6/qml";

  # Ryoku treats these as hard desktop dependencies. Keep them
  # explicit rather than optional so upstream parity cannot
  # silently degrade when a package disappears from nixpkgs.
  # Space Grotesk is part of Google Fonts. Using nixpkgs'
  # generated Google Fonts package avoids carrying another font
  # derivation solely for Ryoku.
  spaceGrotesk = pkgs.google-fonts.override {
    fonts = [ "Space Grotesk" ];
  };

  # waifu2x-ncnn-vulkan is not currently exposed by our pinned
  # nixpkgs. Ryoku therefore carries a pinned upstream runtime
  # package alongside its other first-party dependencies.
  ryokuWaifu2x = ryokuPkgs.ryoku-waifu2x;

  waifu2xModels =
    "${ryokuWaifu2x}/share/waifu2x-ncnn-vulkan/models-cunet";

  # Upstream ships mpv together with mpv-mpris so radio/media
  # playback appears on the desktop's MPRIS bus.
  mpvWithMpris = pkgs.mpv.override {
    scripts = [
      pkgs.mpvScripts.mpris
    ];
  };

  qtQmlPath = lib.makeSearchPath "lib/qt-6/qml" [
    pkgs.qt6.qtdeclarative
    pkgs.qt6.qtmultimedia
    pkgs.qt6.qtwayland
    pkgs.qt6.qt5compat
    pkgs.qt6.qtsvg
    pkgs.qt6.qtimageformats
  ];

  optionalPkg = name:
    lib.optional (builtins.hasAttr name pkgs)
      (builtins.getAttr name pkgs);

  optionalRuntime =
    lib.concatMap optionalPkg [
      "adw-gtk3"
      "gnome-themes-extra"
      "papirus-icon-theme"
      "bibata-cursors"

      "cliphist"
      "yt-dlp"
      "awww"
      "zenity"
      "tesseract"
      "zbar"
      "wf-recorder"
      "hyprsunset"
      "wtype"
      "openrgb"
      "libqalculate"
      "songrec"
      "ddcutil"
      "gamescope"
      "gamemode"
      "mangohud"
      "gpu-screen-recorder"
      "hyprland-preview-share-picker"
    ];

  runtimePackages = with pkgs; [
    # ─────────────────────────────────────────────────────────
    # Ryoku
    # ─────────────────────────────────────────────────────────

    ryokuBundle
    materializer
    ryokuSddmThemeApply
    ryokuSddmTheme
    ryokuPkgs.gpk

    # ─────────────────────────────────────────────────────────
    # Standard userspace expected by Ryoku's shell snippets
    #
    # systemd `path = ...` creates an intentionally restricted
    # service PATH. Without these, even "bash", "sh", "pgrep",
    # "ip", "awk", etc. are invisible to QML Process{}.
    # ─────────────────────────────────────────────────────────

    bash
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    procps
    iproute2
    util-linux
    systemd
    dbus
    which
    file
    less

    # Ryoku terminal / desktop baseline
    bash-completion
    bat
    eza
    fzf
    mise
    zoxide
    gh
    desktop-file-utils
    ryokuWaifu2x

    # ─────────────────────────────────────────────────────────
    # Compositor / shell
    # ─────────────────────────────────────────────────────────

    quickshell
    ryokuHyprPlugins

    # ─────────────────────────────────────────────────────────
    # Qt / QML
    # ─────────────────────────────────────────────────────────

    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtwayland
    qt6.qt5compat
    qt6.qtsvg
    qt6.qtimageformats
    qt6Packages.qt6ct
    kdePackages.syntax-highlighting

    # ─────────────────────────────────────────────────────────
    # Session / portals / secrets
    # ─────────────────────────────────────────────────────────

    gnome-keyring
    xdg-desktop-portal-gtk

    # ─────────────────────────────────────────────────────────
    # Desktop applications
    # ─────────────────────────────────────────────────────────

    kitty
    fish
    starship
    fastfetch
    yazi
    neovim
    nautilus
    nautilus-python

    # ─────────────────────────────────────────────────────────
    # Ryoku command dependencies
    # ─────────────────────────────────────────────────────────

    hypridle
    brightnessctl
    playerctl

    pipewire
    wireplumber
    pulseaudio

    mpvWithMpris
    wl-clipboard
    hyprpicker
    grim
    slurp
    cava

    jq
    imagemagick
    matugen
    ffmpeg
    openssl
    nvibrant
    vulkan-tools
    ryokuCursorMaterial

    bibata-cursors
    vimix-cursors
    phinger-cursors
    apple-cursor

    # ─────────────────────────────────────────────────────────
    # Networking / hardware
    # ─────────────────────────────────────────────────────────

    networkmanager
    iwd
    iw
    bluez

    upower
    power-profiles-daemon
    pavucontrol

    # ─────────────────────────────────────────────────────────
    # Shell probes used by panels/settings
    # ─────────────────────────────────────────────────────────

    fd
    inxi
    lm_sensors
    mako
    pciutils
    usbutils

    # ─────────────────────────────────────────────────────────
    # Misc
    # ─────────────────────────────────────────────────────────

    python3

    # Rashin setup/runtime prerequisites. Rashin itself remains
    # opt-in; these mirror the dependencies of the upstream package.
    uv
    nodejs
    gcc
    sqlite

    curl
    glib
    libnotify
    xdg-utils
  ] ++ optionalRuntime;

  # Number of direct packages in the final NixOS system profile.
  #
  # This deliberately counts environment.systemPackages rather than
  # walking the Nix store closure. The latter includes dependencies and
  # gives misleadingly huge package totals in the Ryoku profile page.
  systemPackageCount =
    builtins.length (
      lib.unique (
        map toString config.environment.systemPackages
      )
    );

  # The Ryoku service can be requested before the display manager's
  # Hyprland process has exported WAYLAND_DISPLAY into systemd.
  #
  # Rather than starting the daemon with WAYLAND_DISPLAY="", wait for
  # the manager environment to contain a real, live Wayland socket and
  # then exec the daemon with that exact session environment.
  ryokuSessionLauncher =
    pkgs.writeShellScript "ryoku-shell-session-launcher" ''
      set -euo pipefail

      # Ryoku's service has a deterministic Nix PATH containing its own
      # runtime dependencies. Launcher entries, however, may point to
      # arbitrary applications installed by the user or system.
      #
      # Preserve Ryoku's dependencies first, then expose the normal
      # NixOS/user executable locations so .desktop Exec commands work.
      export PATH="$PATH:/run/current-system/sw/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:$HOME/.local/bin"

      get_manager_env() {
        manager_env="$(
          ${pkgs.systemd}/bin/systemctl \
            --user show-environment 2>/dev/null || true
        )"

        printf '%s\n' "$manager_env" |
          ${pkgs.gnused}/bin/sed -n "s/^$1=//p" |
          ${pkgs.coreutils}/bin/head -n 1
      }

      attempts=0

      while [ "$attempts" -lt 300 ]; do
        runtime_dir="$(get_manager_env XDG_RUNTIME_DIR)"
        wayland_display="$(get_manager_env WAYLAND_DISPLAY)"

        if [ -z "$runtime_dir" ]; then
          runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$UID}"
        fi

        if [ -n "$wayland_display" ] &&
           [ -S "$runtime_dir/$wayland_display" ]; then

          export XDG_RUNTIME_DIR="$runtime_dir"
          export WAYLAND_DISPLAY="$wayland_display"

          for key in \
            DISPLAY \
            HYPRLAND_INSTANCE_SIGNATURE \
            XDG_CURRENT_DESKTOP \
            XDG_SESSION_DESKTOP \
            XDG_SESSION_TYPE \
            XDG_SESSION_ID
          do
            value="$(get_manager_env "$key")"

            if [ -n "$value" ]; then
              export "$key=$value"
            fi
          done

          exec ${ryokuShell}/bin/ryoku-shell daemon
        fi

        attempts=$((attempts + 1))
        ${pkgs.coreutils}/bin/sleep 0.1
      done

      printf '%s\n' \
        "ryoku-shell: timed out waiting for the Hyprland Wayland socket" >&2

      exit 1
    '';

in
{
  options.programs.ryoku = {
    enable = lib.mkEnableOption "Ryoku desktop";

    shell = lib.mkOption {
      type = lib.types.enum [
        "fish"
        "zsh"
      ];

      default = "fish";

      description = ''
        Interactive shell used by Ryoku on NixOS.

        Fish preserves Ryoku's upstream default. Zsh provides the same
        Starship prompt and core terminal integrations while leaving the
        user's ~/.zshrc untouched.
      '';
    };

    updateFlake = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";

      description = ''
        Flake whose Ryoku input is managed by the Hub update page.
        Only that input is advanced; unrelated Nix inputs are left alone.
      '';
    };

    updateInput = lib.mkOption {
      type = lib.types.str;
      default = "ryoku";

      description = ''
        Name of the Ryoku flake input updated by the NixOS update backend.
      '';
    };

  };

  config = lib.mkIf cfg.enable {
    # apple-cursor is part of Ryoku's cursor catalogue and is unfree in nixpkgs.
    nixpkgs.config.allowUnfreePredicate = lib.mkDefault (
      pkg: lib.getName pkg == "apple_cursor"
    );

    # Preserve Fish as Ryoku's upstream default while allowing Zsh as a
    # declarative NixOS alternative. Explicit per-user shell settings win.
    users.defaultUserShell =
      lib.mkOverride 900 (
        if cfg.shell == "fish"
        then pkgs.fish
        else pkgs.zsh
      );

    programs.fish = lib.mkIf (cfg.shell == "fish") {
      enable = true;
    };

    programs.zsh = lib.mkIf (cfg.shell == "zsh") {
      enable = true;

      shellAliases = {
        ls = "eza -lh --group-directories-first --icons=auto";
        lsa = "eza -lha --group-directories-first --icons=auto";
        lt = "eza --tree --level=2 --long --icons --git";
        lta = "eza --tree --level=2 --long --icons --git -a";
      };

      interactiveShellInit =
        lib.mkAfter (builtins.readFile ../shell/ryoku.zsh);
    };


    programs.hyprland = {
      enable = true;

      # Ryoku requires an exact compositor/plugin ABI match. Do not inherit
      # the host's Hyprland package, which may be older on NixOS stable.
      package = lib.mkForce ryokuHyprland;
      portalPackage = lib.mkForce ryokuHyprlandPortal;

      xwayland.enable = true;
    };

    xdg.portal = {
      enable = true;

      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];

      config.hyprland.default = [
        "hyprland"
        "gtk"
      ];
    };

    security.polkit.enable = true;

    # Ryoku NixOS privileged helper policy.
    #
    # These grants use immutable Nix-store paths instead of Arch's
    # /usr/bin paths. Mutable NetworkManager/Docker helpers are not
    # authorized here; they receive Nix-aware implementations separately.
    security.polkit.extraConfig = lib.mkAfter ''
      polkit.addRule(function (action, subject) {
          if (action.id === "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") === "bluetooth.service" &&
              subject.isInGroup("wheel")) {
              return polkit.Result.YES;
          }
      });

      polkit.addRule(function (action, subject) {
          if (action.id === "org.freedesktop.policykit.exec" &&
              action.lookup("program") === "${ryokuHelpers}/bin/ryoku-power" &&
              subject.local &&
              subject.active &&
              subject.isInGroup("wheel")) {
              return polkit.Result.YES;
          }
      });

      polkit.addRule(function (action, subject) {
          if (action.id === "org.freedesktop.policykit.exec" &&
              action.lookup("program") === "${ryokuHelpers}/bin/ryoku-game-tune" &&
              subject.local &&
              subject.active &&
              subject.isInGroup("wheel")) {
              return polkit.Result.YES;
          }
      });

      polkit.addRule(function (action, subject) {
          var program = action.lookup("program");

          if (action.id === "org.freedesktop.policykit.exec" &&
              (program === "${ryokuHelpers}/bin/ryoku-wifi-powersave" ||
               program === "/run/current-system/sw/bin/ryoku-wifi-powersave") &&
              subject.local &&
              subject.active &&
              subject.isInGroup("wheel")) {
              return polkit.Result.YES;
          }
      });


      // Ryoku NixOS system bridge authorization.
      //
      // Mutable operations enter only through immutable store paths.
      polkit.addRule(function (action, subject) {
          if (action.id !== "org.freedesktop.policykit.exec" ||
              !subject.local ||
              !subject.active ||
              !subject.isInGroup("wheel")) {
              return;
          }

          var program = action.lookup("program");

          if (program === "${ryokuSystemBridge}/bin/ryoku-dns" ||
              program === "${ryokuSystemBridge}/bin/ryoku-wifi-backend" ||
              program === "${ryokuSystemBridge}/bin/ryoku-wifi-regdom" ||
              program === "${ryokuSystemBridge}/bin/ryoku-docker") {
              return polkit.Result.YES;
          }
      });

    '';
    services.gnome.gnome-keyring.enable = true;

    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };

      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Ryoku's networking surface talks to NetworkManager directly.
    # Use mkDefault so hosts with an intentional alternative network
    # stack can still override this.
    networking.networkmanager.enable = lib.mkDefault true;


    # Ryoku NixOS mutable network bridge.
    #
    # Nix owns the /etc path names. Runtime choices live under
    # /var/lib/ryoku rather than rewriting generated NixOS files.
    systemd.tmpfiles.rules = lib.mkAfter [
      "d /var/lib/ryoku 0755 root root -"
      "d /var/lib/ryoku/network 0755 root root -"
      "f /var/lib/ryoku/network/wifi-backend.conf 0644 root root -"
      "f /var/lib/ryoku/network/dns.conf 0644 root root -"
      "f /var/lib/ryoku/network/regdom 0644 root root -"
      "f /var/lib/ryoku/network/iwd.conf 0644 root root -"
    ];

    environment.etc."NetworkManager/conf.d/90-ryoku-wifi-backend.conf" = {
      source = "/var/lib/ryoku/network/wifi-backend.conf";
      mode = "direct-symlink";
    };

    environment.etc."NetworkManager/conf.d/91-ryoku-dns.conf" = {
      source = "/var/lib/ryoku/network/dns.conf";
      mode = "direct-symlink";
    };

    environment.etc."iwd/main.conf" = {
      source = "/var/lib/ryoku/network/iwd.conf";
      mode = "direct-symlink";
    };

    # iwd is available as Ryoku's alternative NetworkManager backend,
    # but NixOS does not statically select or start it.
    services.dbus.packages = lib.mkAfter [
      pkgs.iwd
    ];

    systemd.packages = lib.mkAfter [
      pkgs.iwd
    ];

    # Re-apply a persisted regulatory domain before networking.
    # With no configured country this is intentionally a no-op.
    systemd.services.ryoku-network-regdom = {
      description =
        "Restore Ryoku wireless regulatory domain";

      wantedBy = [
        "network-pre.target"
      ];

      before = [
        "NetworkManager.service"
        "iwd.service"
        "wpa_supplicant.service"
      ];

      after = [
        "systemd-modules-load.service"
        "systemd-tmpfiles-setup.service"
      ];

      serviceConfig = {
        Type = "oneshot";

        ExecStart =
          "${ryokuSystemBridge}/bin/ryoku-wifi-regdom apply";
      };
    };

    # NetworkManager reads Ryoku's persisted override itself.
    # This unit merely makes sure only the selected supplicant owns
    # the radio after boot.
    systemd.services.ryoku-network-backend = {
      description =
        "Reconcile Ryoku NetworkManager Wi-Fi backend";

      wantedBy = [
        "multi-user.target"
      ];

      wants = [
        "NetworkManager.service"
      ];

      after = [
        "NetworkManager.service"
      ];

      serviceConfig = {
        Type = "oneshot";

        ExecStart =
          "${ryokuSystemBridge}/bin/ryoku-wifi-backend reconcile";
      };
    };

    # NixOS owns Docker installation. Ryoku may start it lazily for
    # its tightly-scoped Cobalt container workflow.
    virtualisation.docker = {
      enable = lib.mkDefault true;
      enableOnBoot = lib.mkDefault false;
    };

    hardware.bluetooth = {
      enable = lib.mkDefault true;
      powerOnBoot = lib.mkDefault true;

      settings = {
        General = {
          Experimental = lib.mkDefault true;
          FastConnectable = lib.mkDefault true;
          JustWorksRepairing = lib.mkDefault "always";
          MultiProfile = lib.mkDefault "multiple";
        };

        Policy = {
          AutoEnable = lib.mkDefault true;
        };
      };
    };

    services.upower.enable = lib.mkDefault true;
    services.power-profiles-daemon.enable = lib.mkDefault true;

    boot.kernelModules = lib.mkAfter [
      "i2c-dev"
      "uinput"
    ];

    boot.extraModprobeConfig = lib.mkAfter ''
      options snd_hda_intel power_save=0 power_save_controller=N

      options btusb enable_autosuspend=0
      options bluetooth disable_ertm=1
    '';

    users.groups.i2c = { };

    services.udev.packages = lib.mkAfter [
      ryokuUdevRules
    ];

    # Ryoku's clamshell daemon is the only component that inhibits
    # lid suspend, and only while on AC with an external display.
    environment.etc."systemd/logind.conf.d/10-ryoku-lid.conf".text = ''
      [Login]
      HandleLidSwitch=suspend
      HandleLidSwitchExternalPower=suspend
      HandleLidSwitchDocked=suspend
      InhibitDelayMaxSec=15
    '';

    # Seed the mutable SDDM payload once. Generation switches preserve a
    # user-selected RyoStore theme; a missing/broken state falls back to Orbital.
    system.activationScripts.ryokuSddmTheme = ''
      if [ ! -f /var/lib/ryoku/sddm-theme/Main.qml ]; then
        ${pkgs.coreutils}/bin/install -d -m 0755 /var/lib/ryoku
        ${pkgs.coreutils}/bin/rm -rf /var/lib/ryoku/sddm-theme

        ${pkgs.coreutils}/bin/cp -a \
          ${ryokuDesktopData}/share/ryoku/lockscreen/qylock/themes/clockwork/orbital \
          /var/lib/ryoku/sddm-theme

        ${pkgs.coreutils}/bin/chown -R root:root /var/lib/ryoku/sddm-theme
        ${pkgs.coreutils}/bin/chmod -R a+rX /var/lib/ryoku/sddm-theme
      fi
    '';

    environment.systemPackages =
      runtimePackages;


    # Ryoku's login greeter. Plasma enables SDDM on systems which ship it;
    # this overrides Plasma's default Breeze choice without overriding an
    # explicit user-selected SDDM theme.
    services.displayManager.sddm =
      lib.mkIf config.services.displayManager.sddm.enable {
        theme = lib.mkOverride 900 "ryoku";

        extraPackages = [
          ryokuSddmTheme
          pkgs.qt6.qt5compat
          pkgs.qt6.qtdeclarative
          pkgs.qt6.qtmultimedia
          pkgs.qt6.qtsvg
        ];
      };

    # NixOS uses Ryoku's Nix-only update backend; the Arch transaction stays disabled.
    # Session scope also covers Hub instances launched directly.
    environment.sessionVariables = {
      RYOKU_NIX_SYSTEM_BRIDGE = "1";
      RYOKU_DOCKER_HOST_MANAGED = "1";
      RYOKU_UPDATE_BACKEND = "nix";
      RYOKU_NIX_FLAKE = cfg.updateFlake;
      RYOKU_NIX_INPUT = cfg.updateInput;
      RYOKU_SYSTEM_UPDATES_EXTERNAL = "0";

      # Ryowalls and Ryoshot normally use Arch's /usr/share
      # model path. Point them at the immutable nixpkgs payload.
      RYOKU_WAIFU2X_MODELS = waifu2xModels;
    };

    environment.etc."ryoku/nix-system-package-count".text =
      "${toString systemPackageCount}\n";

    fonts.packages =
      [
        pkgs.inter
        pkgs.fraunces
        spaceGrotesk
        ryokuMapleMonoNF

        pkgs.nerd-fonts.jetbrains-mono
        pkgs.nerd-fonts.space-mono
        pkgs.nerd-fonts.fira-code
        pkgs.nerd-fonts.hack
        pkgs.noto-fonts
        pkgs.noto-fonts-color-emoji
      ]
      ++ optionalPkg "noto-fonts-cjk-sans"
      ++ optionalPkg "material-symbols";

    systemd.user.targets.hyprland-session = {
      description = "Ryoku Hyprland session";

      wants = [
        "graphical-session-pre.target"
        "xdg-desktop-autostart.target"
      ];

      after = [
        "graphical-session-pre.target"
      ];

      before = [
        "graphical-session.target"
        "xdg-desktop-autostart.target"
      ];

      bindsTo = [
        "graphical-session.target"
      ];
    };

    # Rashin is optional at the application level: the service
    # exists on every Ryoku system, while `serve --if-enabled`
    # exits immediately until the user enables Rashin.
    # Work around the BlueZ A2DP reconnect regression after
    # the user's PipeWire/WirePlumber session is available.
    # Hypridle must run on both laptops and desktops.
    #
    # Upstream's `ryoku-idle start` intentionally launches Hypridle only on
    # laptops. That policy is fine on Arch, but on NixOS the daemon also owns
    # desktop session locking, DPMS and pre-suspend locking. Systemd therefore
    # owns the daemon lifecycle while `ryoku-idle on-ac/on-battery` continues
    # to gate the individual timeout actions.
    systemd.user.services.hypridle = {
      description = "Ryoku idle and session lock daemon";

      wantedBy = [
        "hyprland-session.target"
      ];

      partOf = [
        "hyprland-session.target"
      ];

      requires = [
        "ryoku-materialize.service"
      ];

      after = [
        "ryoku-materialize.service"
      ];

      path = runtimePackages;

      restartTriggers = [
        materializer
      ];

      serviceConfig = {
        ExecStart =
          "${pkgs.hypridle}/bin/hypridle -c %h/.config/hypr/hypridle.conf";

        Restart = "on-failure";
        RestartSec = "1s";
      };
    };

    systemd.user.services.ryoku-bluetooth-reset = {
      description =
        "Reset the Bluetooth controller once the Ryoku audio session is ready";

      wantedBy = [
        "hyprland-session.target"
      ];

      partOf = [
        "hyprland-session.target"
      ];

      after = [
        "hyprland-session.target"
        "wireplumber.service"
      ];

      unitConfig = {
        ConditionPathExistsGlob = "/sys/class/bluetooth/*";
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart =
          "${pkgs.systemd}/bin/systemctl restart bluetooth.service";
        TimeoutStartSec = 30;
      };
    };

    systemd.user.services.ryoku-rashin = {
      description = "Ryoku Rashin local agent OS daemon and dashboard";

      wantedBy = [
        "default.target"
      ];

      path = runtimePackages;

      unitConfig = {
        StartLimitIntervalSec = 0;
      };

      serviceConfig = {
        ExecStart =
          "${ryokuRashin}/bin/ryoku-rashin serve --if-enabled";

        Restart = "on-failure";
        RestartSec = 2;
        NoNewPrivileges = true;
      };
    };

    # Refresh the AI usage caches consumed by Ryoku's bar.
    #
    # These mirror upstream's ryoku-ai-usage.service/timer, but
    # point directly at immutable Nix-store helpers instead of
    # Arch's /usr/bin paths.
    systemd.user.services.ryoku-ai-usage = {
      description = "Ryoku AI usage collectors";

      serviceConfig = {
        Type = "oneshot";

        ExecStart = [
          "-${ryokuDesktopData}/bin/claude-usage"
          "-${ryokuDesktopData}/bin/codex-usage"
          "-${ryokuDesktopData}/bin/opencode-usage"
        ];
      };
    };

    systemd.user.timers.ryoku-ai-usage = {
      description = "Ryoku AI usage collector schedule";

      wantedBy = [
        "timers.target"
      ];

      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "10min";
        Persistent = true;
      };
    };

    # Keep Ryoku's materialized user configuration in lockstep with
    # the active Nix generation. Upstream intentionally materializes
    # writable base files into ~/.config rather than running them
    # directly from the package store.
    systemd.user.services.ryoku-materialize = {
      description = "Materialize the current Ryoku desktop generation";

      before = [
        "ryoku-shell.service"
      ];

      wantedBy = [
        "hyprland-session.target"
      ];

      restartTriggers = [
        materializer
        qylockMaterializer
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        # Materialization rewrites the live Ryoku config tree. Hyprland
        # normally watches its config and reloads on every change, which can
        # expose a partially materialized tree during `nixos-rebuild switch`.
        # Quiesce autoreload for the transaction, then reload exactly once.
        ExecStart = pkgs.writeShellScript "ryoku-materialize-live" ''
          set -eu

          reload_hyprland=0

          if ${ryokuHyprland}/bin/hyprctl             keyword misc:disable_autoreload true             >/dev/null 2>&1
          then
            reload_hyprland=1
          fi

          cleanup() {
            if [ "$reload_hyprland" -eq 1 ]; then
              ${ryokuHyprland}/bin/hyprctl reload                 >/dev/null 2>&1 || true
            fi
          }

          trap cleanup EXIT

          ${materializer}/bin/ryoku-materialize
        '';

        ExecStartPost =
          "${qylockMaterializer}";
      };
    };

    systemd.user.services.ryoku-shell = {

      requires = [
        "ryoku-materialize.service"
      ];
      description = "Ryoku shell daemon";

      wantedBy = [
        "hyprland-session.target"
      ];

      partOf = [
        "hyprland-session.target"
      ];

      after = [
        "hyprland-session.target"
        "ryoku-materialize.service"
      ];

      path = runtimePackages;

      environment = {

        RYOKU_DOCKER_HOST_MANAGED = "1";

        RYOKU_NIX_SYSTEM_BRIDGE = "1";
        RYOKU_POLKIT_AGENT = "1";
        RYOKU_SYSTEMD_RUN = "${pkgs.systemd}/bin/systemd-run";

        # NixOS owns system generations. The Hub may advance only the
        # configured Ryoku flake input through the Nix update backend.
        RYOKU_UPDATE_BACKEND = "nix";
        RYOKU_NIX_FLAKE = cfg.updateFlake;
        RYOKU_NIX_INPUT = cfg.updateInput;
        RYOKU_SYSTEM_UPDATES_EXTERNAL = "0";
        RYOKU_WAIFU2X_MODELS = waifu2xModels;

        QT_MEDIA_BACKEND = "ffmpeg";
        QT_FFMPEG_DECODING_HW_DEVICE_TYPES = "";

        QML_IMPORT_PATH =
          "${qmlRoot}:${qtQmlPath}";

        QML2_IMPORT_PATH =
          "${qmlRoot}:${qtQmlPath}";
      };

      unitConfig = {
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5;
      };

      serviceConfig = {
        ExecStartPre =
          "-${ryokuShell}/bin/ryoku-shell quit";

        ExecStart =
          ryokuSessionLauncher;

        Restart = "always";
        RestartSec = 2;

        # User applications are launched into independent app.slice scopes,
        # so the shell can safely own and clean up its complete process tree.
        KillMode = "control-group";
        Slice = "session.slice";
      };
    };
  };
}
