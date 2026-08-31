{ pkgs, src }:

let
  # Depth uses the rembg Python API directly. Keep the runtime inside Nix
  # instead of creating a mutable pip environment on NixOS.
  depthPython = pkgs.python3.withPackages (ps: [
    ps.rembg
  ]);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "ryoku-helpers";
  version = "unstable";

  inherit src;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec"

    install_helpers() {
      for helper in "$@"; do
        [ -f "$helper" ] || continue

        case "$helper" in
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

    # Depth foreground cutout helper.
    #
    # Upstream provisions rembg into a user venv. NixOS instead supplies
    # rembg declaratively and keeps only downloaded model data in user state.
    install -Dm755 \
      ryoku/shell/scripts/ryoku-depth \
      "$out/libexec/ryoku-depth"

    cat > "$out/bin/ryoku-depth" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

real="@REAL@"
python="@PYTHON@"

export PATH="@DEPTH_BIN@:$PATH"

if [[ ''${1:-} != install ]]; then
  exec "$real" "$@"
fi

shift

state="''${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/depth"
models="$state/models"

export REMBG_HOME="$models"
export U2NET_HOME="$models"

mkdir -p "$models"

if (( $# == 0 )); then
  set -- u2netp
fi

for model in "$@"; do
  case "$model" in
    u2netp|birefnet-general-lite)
      ;;
    *)
      printf 'ryoku-depth: unsupported model: %s\n' "$model" >&2
      exit 2
      ;;
  esac

  printf 'Downloading model %s...\n' "$model"

  "$python" - "$model" <<'PY'
import sys

import onnxruntime as ort
from rembg import new_session

model = sys.argv[1]

available = set(ort.get_available_providers())
providers = [
    provider
    for provider in ("CUDAExecutionProvider", "CPUExecutionProvider")
    if provider in available
]

try:
    if providers:
        new_session(model, providers=providers)
    else:
        new_session(model)
except TypeError:
    new_session(model)
PY
done

exec "$real" check
SH

    substituteInPlace "$out/bin/ryoku-depth" \
      --replace-fail '@REAL@' "$out/libexec/ryoku-depth" \
      --replace-fail '@PYTHON@' "${depthPython}/bin/python3" \
      --replace-fail '@DEPTH_BIN@' "${depthPython}/bin"

    chmod 755 "$out/bin/ryoku-depth"

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
