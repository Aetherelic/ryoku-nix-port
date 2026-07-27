#!/usr/bin/env bash
# add (on) or drop (off) the Ryoku shell keybinds on the live session so the
# real bindings can be exercised. overrides yours until `hyprctl reload`.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
bin="$here/ipc/ryoku-shell"

binds=(
	"SUPER,Space,exec,$bin launcher"
	"SUPER,L,exec,$bin lock"
	"SUPER,Escape,exec,$bin menu quick-settings"
	"SUPER,W,exec,$bin menu wallpaper"
	"SUPER,S,exec,$bin menu screenshot"
	"SUPER,C,exec,$bin wallpaper-switcher"
	"SUPER,Tab,exec,$bin overview"
)

case "${1:-on}" in
on)
	for b in "${binds[@]}"; do hyprctl keyword bind "$b" >/dev/null; done
	echo "keybinds added. restore yours with: hyprctl reload"
	;;
off)
	for b in "${binds[@]}"; do hyprctl keyword unbind "${b%%,exec,*}" >/dev/null; done
	echo "keybinds removed"
	;;
*)
	echo "usage: dev-binds.sh [on|off]" >&2
	exit 1
	;;
esac
