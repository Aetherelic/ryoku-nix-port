#!/usr/bin/env bash
# A Kepler GPU must select NVIDIA's 470xx legacy branch. 580xx can provide an
# on-disk module but does not support GK208/GeForce GT 710, which then leaves
# Nouveau blacklisted with no driver able to bind the display or HDMI audio.
set -euo pipefail

ROOT=${RYOKU_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
driver="$ROOT/system/hardware/drivers/nvidia.sh"

[[ -x $driver ]] || { echo "missing driver policy: $driver" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"

cat >"$work/bin/lspci" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '01:00.0 VGA compatible controller: NVIDIA Corporation GK208B [GeForce GT 710] (rev a1)'
EOF

cat >"$work/bin/pacman" <<'EOF'
#!/usr/bin/env bash
# No NVIDIA package is installed: exercise the installer selection branch.
exit 1
EOF

cat >"$work/bin/pacman-conf" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$work/bin"/*

out=$(PATH="$work/bin:$PATH" RYOKU_DRYRUN=1 bash "$driver")
[[ $out == *'Kepler GPU, using the legacy 470xx branch (nvidia-470xx-dkms).'* ]] || {
  printf 'expected 470xx for GK208/GT 710, got:\n%s\n' "$out" >&2
  exit 1
}

echo "nvidia driver selection: OK"
