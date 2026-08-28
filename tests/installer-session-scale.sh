#!/usr/bin/env bash
# fixture test for the display-scale helpers in the live installer session
# (installation/iso/airootfs/usr/local/bin/ryoku-installer-session).
#
# The installer's usable size is a character grid, and a grid is panel pixels
# divided by a font cell. Nothing in the terminal stack scales for you: bubbletea
# only ever learns columns and rows. So a FIXED font size means the grid swings
# with the panel, which is how a fresh install ended up with the step rail off the
# left edge and the confirm buttons off the bottom -- 1366x768 at the old fixed
# 14pt is a 30-row grid, and the Review screen wants more.
#
# These helpers pick the cell from the panel instead. What has to hold:
#   - 1080p still gets exactly 14pt, so the resolution that already works today
#     renders byte-identically and this change cannot regress it;
#   - every panel from 480p to 4K keeps a grid roomy enough for the installer;
#   - the console path measures the FRAMEBUFFER, never the DRM fallback, because
#     it runs exactly when DRM is absent, and it leaves the font alone when it
#     cannot measure.
#
# Pure arithmetic and sysfs reads: no display, no GPU, no root. The probes read
# $RYOKU_SYSFS, so a fake tree stands in for /sys.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
session="$here/../installation/iso/airootfs/usr/local/bin/ryoku-installer-session"
fail() { echo "FAIL: $1" >&2; exit 1; }

[[ -r $session ]] || fail "session script not found at $session"

# Pull in just the helpers; sourcing the whole script would start an installer.
lib=$(mktemp)
trap 'rm -f "$lib"' EXIT
sed -n '/^sysfs=/p;/^native_res()/,/^}/p;/^fb_res()/,/^}/p;/^foot_pt()/,/^}/p;/^console_font()/,/^}/p' "$session" >"$lib"
for fn in native_res fb_res foot_pt console_font; do
  grep -q "^$fn()" "$lib" || fail "could not extract $fn from the session script"
done

# The graphical kiosk must pin to a single output, or cage spans the foot window
# across every connected monitor and the installer stretches over the bezel (#87).
grep -qE 'cage -m last' "$session" || fail "graphical kiosk must run 'cage -m last' to stay on one monitor"
# shellcheck source=/dev/null
source "$lib"

# foot's cell, from its own source: with dpi-aware=no (its default since 1.16)
# px = round(pt * scale * 4/3), and JetBrains Mono measures 0.6em wide by 1.32em
# tall (units_per_em 1000, advance 600, ascender 1020 + descender 300).
cell_w() { echo $(((6 * ((4 * $1 + 1) / 3) + 5) / 10)); }
cell_h() { echo $(((132 * ((4 * $1 + 1) / 3) + 50) / 100)); }

# The grid the TUI is verified to render every critical element into is 80x24
# (installation/tui/layout_test.go). Demand real headroom over it so a panel we
# have not seen still lands comfortably inside.
min_cols=88
min_rows=28

# 1. the no-regression anchor: 1080p must still be exactly 14pt.
[[ $(foot_pt 1080) == 14 ]] || fail "1080p must stay 14pt, got $(foot_pt 1080)"

# 2. text scales with the panel instead of staying fixed, in both directions.
(($(foot_pt 2160) > $(foot_pt 1080))) || fail "4K must get a larger font than 1080p"
(($(foot_pt 768) < $(foot_pt 1080))) || fail "768p must get a smaller font than 1080p"

# 3. clamped at both ends so a freak mode cannot produce a silly size.
[[ $(foot_pt 200) == 8 ]] || fail "tiny panel must clamp to 8pt, got $(foot_pt 200)"
[[ $(foot_pt 8000) == 32 ]] || fail "huge panel must clamp to 32pt, got $(foot_pt 8000)"
# An unmeasurable panel falls back to the 1080p default rather than the floor:
# native_res reports 1920x1080 when DRM is silent, so the two agree.
[[ $(foot_pt 0) == 14 ]] || fail "unknown height must fall back to the 1080p size, got $(foot_pt 0)"

# 4. the real point: across every panel the installer actually meets, the kiosk
#    grid stays big enough for the wizard.
while read -r w h; do
  pt=$(foot_pt "$h")
  cols=$((w / $(cell_w "$pt")))
  rows=$((h / $(cell_h "$pt")))
  ((cols >= min_cols)) || fail "${w}x${h} at ${pt}pt gives only $cols columns (need $min_cols)"
  ((rows >= min_rows)) || fail "${w}x${h} at ${pt}pt gives only $rows rows (need $min_rows)"
done <<'EOF'
640 480
800 600
1024 768
1280 720
1366 768
1600 900
1920 1080
1920 1200
2560 1440
2560 1600
3440 1440
3840 2160
EOF

# 5. the console ladder never trades reachable content for bigger text: whatever
#    font it picks, the resulting VT grid still clears the same bar.
while read -r w h; do
  case $(console_font "$w" "$h") in
    solar24x32) cw=24 ch=32 ;;
    latarcyrheb-sun32) cw=16 ch=32 ;;
    iso01-12x22) cw=12 ch=22 ;;
    default8x16) cw=8 ch=16 ;;
    *) fail "console_font returned an unknown font for ${w}x${h}" ;;
  esac
  ((w / cw >= 80 && h / ch >= 24)) || fail "console font for ${w}x${h} leaves $((w / cw))x$((h / ch))"
done <<'EOF'
640 480
800 600
1024 768
1366 768
1920 1080
2560 1600
3840 2160
EOF

# 6. a small framebuffer must keep the smallest cell; only a big one may grow.
[[ $(console_font 640 480) == default8x16 ]] || fail "640x480 must keep the 8x16 cell"
[[ $(console_font 3840 2160) != default8x16 ]] || fail "4K must enlarge the console font"

# 7. the console path measures the framebuffer, and stays silent when it cannot.
fake=$(mktemp -d)
trap 'rm -f "$lib"; rm -rf "$fake"' EXIT
# sysfs is read by the sourced probes, not by this script.
# shellcheck disable=SC2034
sysfs=$fake
mkdir -p "$fake/class/graphics/fb0"
printf '640,480\n' >"$fake/class/graphics/fb0/virtual_size"
[[ $(fb_res) == "640 480" ]] || fail "fb_res misread a real virtual_size: $(fb_res)"
printf 'garbage\n' >"$fake/class/graphics/fb0/virtual_size"
fb_res >/dev/null 2>&1 && fail "fb_res must fail on a garbled virtual_size"
rm -f "$fake/class/graphics/fb0/virtual_size"
fb_res >/dev/null 2>&1 && fail "fb_res must fail when the framebuffer is absent"

# 8. native_res prefers a CONNECTED connector's first (native) mode, and falls
#    back to 1080p rather than returning nothing.
[[ $(native_res) == "1920 1080" ]] || fail "no connector must fall back to 1080p, got $(native_res)"
mkdir -p "$fake/class/drm/card0-eDP-1" "$fake/class/drm/card0-HDMI-A-1"
printf 'disconnected\n' >"$fake/class/drm/card0-HDMI-A-1/status"
printf '1024x768\n' >"$fake/class/drm/card0-HDMI-A-1/modes"
printf 'connected\n' >"$fake/class/drm/card0-eDP-1/status"
printf '2560x1600\n1920x1200\n' >"$fake/class/drm/card0-eDP-1/modes"
[[ $(native_res) == "2560 1600" ]] || fail "native_res must take the connected panel's first mode, got $(native_res)"

echo "installer-session-scale: OK"
