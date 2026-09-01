{ pkgs }:

pkgs.writeShellApplication {
  name = "ryoku-install";

  runtimeInputs = with pkgs; [
    coreutils
    diffutils
    git
    gnugrep
    jq
    nix
    python3
    systemd
  ];

  text = ''
    set -euo pipefail

    source_ref="''${RYOKU_INSTALL_SOURCE:-github:aethctl/Ryoku-on-NixOS/main}"
    flake_arg="/etc/nixos"
    assume_yes=0
    dry_run=0

    trusted_root_path="${pkgs.lib.makeBinPath [
      pkgs.coreutils
      pkgs.git
      pkgs.nix
      pkgs.systemd
    ]}:/run/current-system/sw/bin:/run/wrappers/bin"

    run_root() {
      if [ "$(id -u)" -eq 0 ]; then
        "$@"
        return
      fi

      if [ ! -x /run/wrappers/bin/sudo ]; then
        echo "ryoku-install: NixOS sudo wrapper is unavailable at /run/wrappers/bin/sudo" >&2
        exit 1
      fi

      /run/wrappers/bin/sudo \
        ${pkgs.coreutils}/bin/env \
        "PATH=$trusted_root_path" \
        "$@"
    }

    usage() {
      cat <<'EOF'
Usage:
  ryoku-install [options]

Options:
  --flake PATH[#HOST]   NixOS flake to configure (default: /etc/nixos)
  --source REF          Ryoku flake reference
  --dry-run             Show proposed changes without writing them
  -y, --yes             Skip confirmation
  -h, --help            Show this help
EOF
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --flake)
          [ "$#" -ge 2 ] || {
            echo "ryoku-install: --flake requires a value" >&2
            exit 2
          }
          flake_arg="$2"
          shift 2
          ;;
        --source)
          [ "$#" -ge 2 ] || {
            echo "ryoku-install: --source requires a value" >&2
            exit 2
          }
          source_ref="$2"
          shift 2
          ;;
        --dry-run)
          dry_run=1
          shift
          ;;
        -y|--yes)
          assume_yes=1
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          echo "ryoku-install: unknown option: $1" >&2
          usage >&2
          exit 2
          ;;
      esac
    done

    case "$flake_arg" in
      *#*)
        flake_root="''${flake_arg%%#*}"
        host="''${flake_arg#*#}"
        ;;
      *)
        flake_root="$flake_arg"
        host=""
        ;;
    esac

    flake_root="$(readlink -f "$flake_root")"
    flake_file="$flake_root/flake.nix"
    module_file="$flake_root/ryoku.nix"

    [ -f "$flake_file" ] || {
      echo "ryoku-install: no flake.nix found at $flake_root" >&2
      exit 1
    }

    if [ -z "$host" ]; then
      current_host="$(cat /proc/sys/kernel/hostname)"

      show="$(
        nix flake show "path:$flake_root" --json --no-write-lock-file 2>/dev/null ||
        nix flake show "path:$flake_root" --json --impure --no-write-lock-file
      )"

      mapfile -t hosts < <(
        printf '%s\n' "$show" |
          jq -r '.nixosConfigurations // {} | keys[]'
      )

      [ "''${#hosts[@]}" -gt 0 ] || {
        echo "ryoku-install: no nixosConfigurations found" >&2
        exit 1
      }

      for candidate in "''${hosts[@]}"; do
        if [ "$candidate" = "$current_host" ]; then
          host="$candidate"
          break
        fi
      done

      if [ -z "$host" ] && [ "''${#hosts[@]}" -eq 1 ]; then
        host="''${hosts[0]}"
      fi

      if [ -z "$host" ]; then
        echo "ryoku-install: multiple NixOS hosts found:" >&2
        printf '  %s\n' "''${hosts[@]}" >&2
        echo "Re-run with --flake $flake_root#HOST" >&2
        exit 1
      fi
    fi

    if [ -f "$module_file" ] &&
       ! grep -Fq '# Managed by ryoku-install.' "$module_file"
    then
      echo "ryoku-install: $module_file already exists and is not installer-managed" >&2
      echo "Refusing to overwrite it." >&2
      exit 1
    fi

    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"' EXIT

    work_flake="$work_dir/flake.nix"
    work_module="$work_dir/ryoku.nix"

    cp "$flake_file" "$work_flake"

    cat > "$work_module" <<'EOF'
# Managed by ryoku-install.
{ ... }:

{
  programs.ryoku.enable = true;
}
EOF

    python3 - "$work_flake" "$host" "$source_ref" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
host = sys.argv[2]
source = sys.argv[3]

text = path.read_text()

# Add the Ryoku input.
outputs_pos = text.find("outputs")
if outputs_pos < 0:
    raise SystemExit("ryoku-install: could not locate `outputs`")

input_region = text[:outputs_pos]

if not re.search(r"(?m)^[ \t]*ryoku[ \t]*=", input_region):
    match = re.search(r"(?m)^([ \t]*)inputs[ \t]*=[ \t]*\{[ \t]*$", text)

    if not match:
        raise SystemExit(
            "ryoku-install: unsupported flake layout; "
            "expected `inputs = {`"
        )

    indent = match.group(1) + "  "

    block = (
        "\n"
        f"{indent}ryoku = {{\n"
        f'{indent}  url = "{source}";\n'
        f"{indent}}};\n"
    )

    text = text[:match.end()] + block + text[match.end():]

# Add `ryoku` to the outputs arguments.
outputs = re.search(
    r"outputs[ \t]*=[ \t]*"
    r"(?:(?:[A-Za-z_][A-Za-z0-9_]*)[ \t]*@[ \t]*)?"
    r"\{(?P<body>.*?)\}[ \t]*:",
    text,
    re.S,
)

if not outputs:
    raise SystemExit(
        "ryoku-install: unsupported flake layout; "
        "could not parse outputs arguments"
    )

body = outputs.group("body")

if not re.search(r"(?<![A-Za-z0-9_-])ryoku(?![A-Za-z0-9_-])", body):
    if "..." in body:
        updated = body.replace("...", "ryoku, ...", 1)
    else:
        updated = body.rstrip()
        if updated and not updated.endswith(","):
            updated += ","
        updated += " ryoku"

    text = (
        text[:outputs.start("body")]
        + updated
        + text[outputs.end("body"):]
    )

# Locate the requested nixosSystem.
escaped = re.escape(host)

host_patterns = [
    rf'(?m)^[ \t]*(?:"{escaped}"|{escaped})[ \t]*='
    rf'[ \t]*(?:nixpkgs\.lib\.)?nixosSystem[ \t]*\{{',

    rf'(?m)^[ \t]*nixosConfigurations\.'
    rf'(?:"{escaped}"|{escaped})[ \t]*='
    rf'[ \t]*(?:nixpkgs\.lib\.)?nixosSystem[ \t]*\{{',
]

host_start = None

for pattern in host_patterns:
    match = re.search(pattern, text)
    if match:
        host_start = match.start()
        break

if host_start is None:
    systems = list(
        re.finditer(
            r"(?:nixpkgs\.lib\.)?nixosSystem[ \t]*\{",
            text,
        )
    )

    if len(systems) == 1:
        host_start = systems[0].start()
    else:
        raise SystemExit(
            "ryoku-install: could not safely locate "
            f"nixosSystem for host `{host}`"
        )

tail = text[host_start:]

modules = re.search(
    r"(?m)^([ \t]*)modules[ \t]*=[ \t]*\[",
    tail,
)

if not modules:
    raise SystemExit(
        "ryoku-install: target host has no editable `modules = [` list"
    )

modules_start = host_start + modules.end()
modules_close = text.find("];", modules_start)

if modules_close < 0:
    raise SystemExit(
        "ryoku-install: could not locate end of modules list"
    )

segment = text[modules_start:modules_close]
indent = modules.group(1) + "  "

entries = []

if "ryoku.nixosModules.default" not in segment:
    entries.append(f"{indent}ryoku.nixosModules.default")

if "./ryoku.nix" not in segment:
    entries.append(f"{indent}./ryoku.nix")

if entries:
    addition = "\n" + "\n".join(entries)
    text = text[:modules_start] + addition + text[modules_start:]

path.write_text(text)
PY

    printf '\nRyoku NixOS installer\n'
    printf '%s\n' '────────────────────────────────────────'
    printf 'Flake   %s\n' "$flake_root"
    printf 'Host    %s\n' "$host"
    printf 'Source  %s\n' "$source_ref"

    printf '\nProposed flake.nix changes:\n'
    diff -u "$flake_file" "$work_flake" || true

    printf '\nProposed ryoku.nix:\n'
    cat "$work_module"

    if [ "$dry_run" -eq 1 ]; then
      printf '\nDry run complete. No files were changed.\n'
      exit 0
    fi

    if [ "$assume_yes" -ne 1 ]; then
      printf '\nThe new NixOS generation will be built before it is switched.\n'
      printf 'Bootloader, kernel and partition settings are not modified.\n'
      printf 'Continue? [y/N] '

      read -r answer

      case "$answer" in
        y|Y|yes|YES)
          ;;
        *)
          echo "Cancelled."
          exit 0
          ;;
      esac
    fi

    if [ -x /run/current-system/sw/bin/nixos-rebuild ]; then
      nixos_rebuild=/run/current-system/sw/bin/nixos-rebuild
    else
      nixos_rebuild="$(command -v nixos-rebuild || true)"
    fi

    [ -n "$nixos_rebuild" ] || {
      echo "ryoku-install: nixos-rebuild is unavailable" >&2
      exit 1
    }

    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_dir="/var/backups/ryoku-nixos/$timestamp"

    had_lock=0
    had_module=0

    [ -f "$flake_root/flake.lock" ] && had_lock=1
    [ -f "$module_file" ] && had_module=1

    run_root mkdir -p "$backup_dir"
    run_root cp -a "$flake_file" "$backup_dir/flake.nix"

    if [ "$had_lock" -eq 1 ]; then
      run_root cp -a "$flake_root/flake.lock" "$backup_dir/flake.lock"
    fi

    if [ "$had_module" -eq 1 ]; then
      run_root cp -a "$module_file" "$backup_dir/ryoku.nix"
    fi

    rollback() {
      run_root cp -a "$backup_dir/flake.nix" "$flake_file"

      if [ "$had_lock" -eq 1 ]; then
        run_root cp -a "$backup_dir/flake.lock" "$flake_root/flake.lock"
      else
        run_root rm -f "$flake_root/flake.lock"
      fi

      if [ "$had_module" -eq 1 ]; then
        run_root cp -a "$backup_dir/ryoku.nix" "$module_file"
      else
        run_root rm -f "$module_file"
      fi
    }

    run_root cp "$work_flake" "$flake_file"
    run_root install -m 0644 "$work_module" "$module_file"

    printf '\nUpdating flake lock...\n'

    if ! run_root nix flake lock "path:$flake_root"; then
      rollback
      echo "ryoku-install: flake lock failed; files restored" >&2
      exit 1
    fi

    printf '\nBuilding NixOS generation...\n'

    if ! run_root "$nixos_rebuild" build \
      --flake "path:$flake_root#$host"
    then
      rollback
      echo "ryoku-install: build failed; files restored" >&2
      exit 1
    fi

    printf '\nSwitching generation...\n'

    if ! run_root "$nixos_rebuild" switch \
      --flake "path:$flake_root#$host"
    then
      rollback
      echo "ryoku-install: switch failed; configuration files restored" >&2
      exit 1
    fi

    if [ -x /run/current-system/sw/bin/ryoku-materialize ]; then
      /run/current-system/sw/bin/ryoku-materialize
    fi

    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user try-restart ryoku-shell.service >/dev/null 2>&1 || true

    printf '\nRyoku installation complete.\n'
    printf 'Backup: %s\n' "$backup_dir"
  '';
}
