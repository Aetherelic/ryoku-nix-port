{ pkgs, src }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "ryoku-helpers";
  version = "unstable";

  inherit src;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"

    install_helpers() {
      for helper in "$@"; do
        [ -f "$helper" ] || continue

        case "$helper" in
          */ryoku-dns|*/ryoku-wifi-backend|*/ryoku-wifi-regdom|*/ryoku-docker)
            # These mutate Arch-owned system state upstream.
            # NixOS ships immutable bridge implementations instead.
            continue
            ;;
          *.service|*.rules|*.conf)
            continue
            ;;
        esac

        install -Dm755 \
          "$helper" \
          "$out/bin/$(basename "$helper")"
      done
    }

    install_helpers \
      system/hardware/*/ryoku-* \
      system/containers/ryoku-*

    # These are useful desktop helpers. Package-management mutations
    # remain a separate NixOS-porting concern.
    install_helpers \
      system/extras/ryoku-cmd-present

    # RyoStore's upstream bundle actuator mutates pacman/AUR state. NixOS
    # instead exposes a read-only status shim and rejects package mutations
    # with a clear declarative-system message.
    install -Dm755 \
      nix/bridge/ryostore-install \
      "$out/bin/ryostore-install"

    # Settings -> language integration.
    install -Dm755 \
      ryoku/ui/i18n-sync.py \
      "$out/bin/ryoku-i18n"

    runHook postInstall
  '';
  meta = {
    description = "Runtime helper commands used by the Ryoku desktop";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };

}
