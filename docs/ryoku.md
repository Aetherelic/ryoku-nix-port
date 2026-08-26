# What Ryoku is

Ryoku (力, "power") is a hand-built Arch Linux distribution: a complete,
opinionated Hyprland desktop plus the installer and system definition that
reproduce it on any machine. The whole thing lives in this one repository and is
built from it; the live machine is only ever a deployment target.

## Philosophy

Ryoku is built on one belief: a desktop should be ready to live in the moment
it finishes installing. Not ready the way a blank page is ready, but the way a
good tool is. You pick it up, it already works, and it already looks like
someone cared.

Most Hyprland setups hand you freedom the way a hardware store does: here are
the parts, good luck. Want to move the clock, restyle the bar, change the accent
color? Open a config file, learn its syntax, edit it by hand, reload, and hope.
That is not freedom, it is homework, and it quietly tells every newcomer that
this world was not built for them.

Freedom should be simpler than that. You should be able to change your desktop
by using your desktop: open a panel, click a control, watch it happen. No
digging through files, no memorizing options, no editing code to do something as
ordinary as changing how your bar looks. The power is all still there. It is
just within reach.

So Ryoku is not a dotfile repository with good marketing. It is a finished
desktop with a front door: taste already applied, and every choice that matters
put behind a control you can actually find. A beginner gets a real computer on
day one. Everyone else gets to stop babysitting a pile of configs and just use
the thing.

Power and beauty, in that order, and never one without the other, and never
locked behind a text editor.

## Goals

- **A cohesive Wayland desktop.** One look, one motion language, one control
  plane. The bar, panels, launcher, lock screen, and screenshot tool are parts of
  a single shell, not a pile of unrelated widgets.
- **Reproducible.** A fresh install reaches the same desktop the repo describes,
  from one source of truth.
- **Works on day one.** Sensible defaults that are actually usable immediately:
  the developer toolchains and their package managers work without root, theming
  follows the wallpaper, hardware (GPU, displays, laptop power) is detected and
  configured automatically.
- **Minimal and legible.** No cruft, no dead code, no duplicated config. Small,
  focused files you can read.
- **Opinionated by default, swappable by choice.** A fresh install is a
  deliberate set of choices, the stock Arch kernel among them. Where a
  power-user lever is genuinely worth it, Ryoku offers it as an explicit opt-in
  that leaves the default untouched: the Extras section can swap in the CachyOS
  kernel, for one, without changing what a fresh install is. See
  `docs/kernels.md`.

## How the parts fit

- **The shell** (`ryoku/shell/`) is the desktop UI. `quickshell/` is the QML
  front end (the `qsbar` top bar by default, with the built-in `sumi`
  monochrome rail as its alternative, plus the `launcher` and
  `ryoshot` screenshot tool). `ipc/ryoku-shell` is a single Go daemon that is the
  control plane: it supervises the UI components, owns the wallpaper, clipboard,
  and lock, and answers one socket. Keybinds and the UI talk to it; it decides.
- **The control CLI** (`ryoku/cli/`, the `ryoku` command) is the system front
  door: `ryoku update` (snapshot, then pacman and the AUR, then materialize, then
  reload), plus `rollback`, `snapshots`, `status`, and `materialize`. It
  orchestrates pacman, yay, and snapper.
- **Hyprland** (`ryoku/hyprland/`) is the compositor, configured in Lua, one
  concern per module. Its autostart brings up the shell and the hardware helpers.
- **Theming** is wallpaper-driven: `matugen` regenerates the palette from the
  current wallpaper, and the terminal and Hyprland colors follow it. With *Theme
  apps* on (the default), `matugen` fans that same palette into GTK / GUI apps
  (Files, editors, other libadwaita/GTK apps) too; off, they stay stock. Brand-
  fixed elements (the 力 logo, a few accents) stay constant.
- **The system** (`system/`) defines the boot chain, the hardware policy
  (GPU/driver/display/power helper scripts), and the package sets.
- **The installer** (`installation/`) is a Go TUI plus a shell backend that
  partitions, pacstraps the base, adds the `[ryoku]` package repo and installs
  `ryoku-desktop`, and sets up the boot chain. The desktop comes from signed
  packages and the ISO prebuilds the installer, so an install needs no build
  toolchain.
- **Rashin** (`ryoku/rashin/`, optional and off by default) is the agent OS: a
  machine-generated knowledge vault, a local daemon with a web dashboard, and a
  one-click Hermes setup, so any coding agent starts with an exact map of the
  machine. Enabled from Ryoku Settings under Advanced. See `docs/rashin.md`.

## Working on it

Read `docs/structure.md` for where things live, `docs/conventions.md` for how to
write them, `docs/ui-ux.md` for the desktop's design and motion, and
`docs/development.md` for the deploy/test/commit loop. The cardinal rules in
`AGENTS.md` override anything that contradicts them.
