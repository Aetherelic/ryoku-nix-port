<div align="center">

<img src="ryoku/assets/brand/logo-mark-v2.png" alt="Ryoku" width="160" />

# Ryoku on NixOS

**力と美のために** &middot; *For the sake of power and beauty.*

Ryoku is a hand-built Arch Linux distribution. **Ryoku on NixOS** is the official
NixOS port of the Ryoku desktop: one cohesive Hyprland environment, a guided
installer, and a declarative system definition that reproduces it.

The implementation changes. The identity does not. Ryoku remains deliberate in
how it looks, moves, and gets out of your way.

<br />

[![Ryoku](https://img.shields.io/badge/RYOKU-UPSTREAM-E2342A?style=for-the-badge&labelColor=111111)](https://ryoku.dev)
[![NixOS](https://img.shields.io/badge/NIXOS-OFFICIAL_PORT-E2342A?style=for-the-badge&logo=nixos&logoColor=white&labelColor=111111)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/HYPRLAND-DESKTOP-E2342A?style=for-the-badge&logoColor=white&labelColor=111111)](https://hypr.land)
[![License](https://img.shields.io/badge/LICENSE-GPL--3.0-E2342A?style=for-the-badge&labelColor=111111)](LICENSE)

<br />

[![Discord](https://img.shields.io/badge/DISCORD-COMMUNITY-E2342A?style=for-the-badge&logo=discord&logoColor=white&labelColor=111111)](https://discord.gg/8KjBmUEyKA)
[![Reddit](https://img.shields.io/badge/REDDIT-r%2FRYOKUARCH-E2342A?style=for-the-badge&logo=reddit&logoColor=white&labelColor=111111)](https://www.reddit.com/r/RyokuArch/)
[![Docs](https://img.shields.io/badge/DOCS-RYOKU-E2342A?style=for-the-badge&labelColor=111111)](docs/)
[![Structure](https://img.shields.io/badge/PROJECT-STRUCTURE-E2342A?style=for-the-badge&labelColor=111111)](docs/structure.md)

</div>

<div align="center">

## **The Arch version of Ryoku can be found [here](https://github.com/neur0map/ryoku-arch)**

**Credit to [Neur0map](https://github.com/neur0map)**

</div>

---

<div align="center">

<img width="1198" height="852" alt="image" src="https://github.com/user-attachments/assets/2dd299e0-2f95-4b1f-a33d-06e0fa768beb" />

<sub>The Ryoku Hub, a live system dossier. Screenshots are real; the poster art is generated.</sub>

<p>
  <a href="https://youtu.be/kx7VW4Mg0m4">
    <img src="https://img.youtube.com/vi/kx7VW4Mg0m4/maxresdefault.jpg" alt="Ryoku showcase: watch on YouTube" width="640" />
  </a>
  <br />
  <sub>&#9654; <a href="https://youtu.be/kx7VW4Mg0m4">Watch the Ryoku showcase on YouTube</a></sub>
</p>

</div>

---

## About

Ryoku means power, and the name is the point. The power is a modular shell built
to be extended: the desktop is composed of small, independent surfaces, and a
plugin system is on the way, so the shell grows with what you actually use
instead of bloating by default. The beauty is the shell itself, one continuous
and deliberate surface where the bar, panels, launcher, lockscreen, and session
controls move as a single thing: paper and ink, warm bone type on pure black,
with the frame retinting live from your wallpaper. 力と美のために: for the sake
of power and beauty.

The desktop, the installer, and the system definition all live in this
repository, and every machine is built from it; the repository is the single
source of truth, and a live machine is only ever a deployment target. The
desktop is a Hyprland Wayland session authored in Lua with the Quickshell-based
Ryoku shell on top. Ryoku's alpha series was a fork of Omarchy. From the beta
series on, the tree was pruned and rebuilt from an empty root, so the installer,
shell, theming, tooling, and system definition are all Ryoku's own, and the
current codebase shares no code with Omarchy. The shell is custom: its frame-blob
rendering and some animation curves are adapted from Caelestia.

## The desktop

One motion language across every surface, retinted live from your wallpaper.

Click a status widget on the bar and its controls grow out of the rail as a
popout card, then melt back when you are done.

On first login a short welcome walks you through the desktop: the handful of
keybinds that open almost everything, and a few choices you can make on the
spot, the interface scale, the bar, and which desktop widgets to show.
Everything else waits in Ryoku Settings (`Super + ,`).

<table>
  <tr>
    <td width="50%">
     <img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/44767ade-9cbf-4ef1-ab4b-fcb4d0f7a8a0" /><br />
      <sub><b>The desktop.</b> The bar on one edge, the dock on the other, a clock on the wallpaper, and nothing else asking for attention.</sub>
    </td>
    <td width="50%">
      <img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/688952e0-c8d9-4fd4-9bd1-cd9b5af09963" /><br />
      <sub><b>Launcher.</b> At rest it is a clock, the weather, and a plate of art. Type and apps, commands, files, packages, radio and the calculator come out of one search.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="docs/media/controls.webp" alt="Control sidebar" width="100%" /><br />
      <sub><b>Control sidebar.</b> Session, connect tiles, sound and brightness, media, calendar, and the power profile on one rail.</sub>
    </td>
    <td width="50%">
      <img src="docs/media/batgirl.webp" alt="A full rice" width="100%" /><br />
      <sub><b>One wallpaper.</b> The bar, widgets, and frame all retint from it.</sub>
    </td>
  </tr>
</table>

## What ships

- **The desktop** under `ryoku/`: a Hyprland session authored in Lua (not a
  hand-written `hyprland.conf`), the Quickshell-based Ryoku shell, the
  lockscreen, app configs, and brand assets.
- **The system definition** under `system/`: the boot chain, hardware policy,
  and package sets that make a machine a Ryoku machine.
- **The installer** under `installation/`: a guided TUI, the backend installer,
  and the archiso profile that builds the signed ISO.
- **The update system** under `release/`: the `ryoku` control CLI, the desktop
  packages, and the signed `[ryoku]` pacman repository.

## Requirements

Ryoku is `x86_64` only and boots in UEFI mode. The session is Wayland: Hyprland
with the GPU-composited Ryoku shell on top. The installer refuses a machine with
Secure Boot on (Limine ships unsigned) unless you have enrolled your own keys,
and there is no 32-bit build and no legacy BIOS path.

|  | Minimum | Recommended |
|---|---|---|
| CPU | 64-bit x86_64, dual-core | quad-core or better |
| RAM | 4 GB | 8 GB, 16 GB with the dev toolchains |
| GPU | any card with working KMS and OpenGL/Vulkan | recent integrated or discrete |
| Storage | 32 GB (installer floor) | 64 GB+ SSD |
| Firmware | UEFI, Secure Boot off | UEFI, Secure Boot off |

The desktop is light on its own: a resting session (the compositor, the shell,
and its daemons) uses under 1 GB of RAM. What you run on top, the browser,
editor, and toolchains, is the rest of the budget: 8 GB is a sensible floor for
daily use, and 16 GB is comfortable once the language toolchains are in. The
32 GB disk figure is the installer's hard floor. The base plus developer and
desktop package closure is about 13 to 15 GB, and the root filesystem needs 20 GB
before swap so Btrfs snapshots and AUR builds have somewhere to go. Use an SSD;
snapshots on every `ryoku update`, package builds, and the shell itself all feel
a slow disk.

### Graphics

The shell is an accelerated Qt surface (live blur, the blob frame, motion
throughout), so it wants a real GPU with working DRM/KMS. Software rendering will
start but will not feel good. Anything from roughly the last decade is fine, and
the right driver is picked for the detected hardware at install time:

- **AMD** the open Mesa stack and the RADV Vulkan driver (GCN and newer, on
  amdgpu). No proprietary blob, nothing to install by hand.
- **Intel** Broadwell (Gen8) and newer, on i915 or the newer Xe driver, with the
  modern media driver and the ANV Vulkan driver.
- **NVIDIA** the open kernel modules on Turing and newer (GTX 16-series, RTX
  20-series and up), the proprietary modules on older Maxwell, Pascal, and Volta
  cards. On the stock kernel Ryoku installs the prebuilt module, so there is no
  DKMS build to fail on first boot.

On a hybrid laptop with two GPUs, Ryoku ranks them and pins the strongest as the
primary renderer on a desktop, while a laptop keeps the integrated GPU primary
for battery; an external GPU always wins. Every GPU stays available, so a monitor
on a second card still lights up, and dense HiDPI panels are scaled on first
login.

The playbook for awkward hardware (Intel VMD, NVIDIA modeset, Windows dual-boot,
Broadcom Wi-Fi, read-only NVRAM, slow USB media) is in
[`docs/installation-hardware.md`](docs/installation-hardware.md).

## Install

Ryoku for NixOS installs on top of an existing **flake-based NixOS system**.
It does not repartition the disk or replace NixOS itself; the installer adds the
Ryoku flake and module to your existing configuration, builds a new NixOS
generation, and switches to it.

### Existing NixOS installation

The recommended installation method is the Ryoku NixOS installer:

```bash
nix run github:Aetherelic/Ryoku-on-NixOS/main#install
```

Preview everything the installer would change without writing anything:

```bash
nix run github:Aetherelic/Ryoku-on-NixOS/main#install -- --dry-run
```

The dry run shows the proposed `flake.nix` changes and the generated `ryoku.nix`
module, but does not modify your system.

The installer expects 
/etc/nixos/
├── flake.nix
├── flake.lock
└── configuration.nix
to already exist, Flakes need to be avaliable before attempting to install.

> [!WARNING]
> The NixOS installer is still relatively new and is being tested across different
> flake layouts, hardware configurations, and existing NixOS setups.
>
> It modifies your existing NixOS flake and creates an installer-managed
> `ryoku.nix`, so **back up your configuration before installing**.
>
> Before making changes, the installer stores copies of the affected configuration
> under `/var/backups/ryoku-nixos/`. It also builds the new NixOS generation before
> switching to it, and restores the previous configuration files if the flake lock,
> build, or switch fails.
>
> Run the installer as your normal user; it will request `sudo` only when system
> changes are required. Using `--dry-run` first is recommended on heavily customized
> NixOS configurations.

## Updating

Ryoku updates through the same command:

```bash
ryoku update
```

On NixOS, this does **not** run Pacman or modify Arch packages like the Arch variant. Ryoku uses its
Nix-specific update backend, updates only the configured Ryoku flake input, then
builds and switches to the resulting NixOS generation.

The NixOS implementation follows its own Ryoku source and version lifecycle.
Arch package releases, the `[ryoku]` Pacman repository, and AUR updates do not
control the NixOS release.

Because updates produce normal NixOS generations, the previous system remains
available through the standard NixOS rollback mechanisms if an update causes a
problem.

Your Ryoku settings are preserved across updates. Packaged desktop files are
reconciled to the version shipped by Ryoku, while user-owned overrides remain
separate and load afterwards so your customizations can continue to take
precedence.

On developer installations using a local `path:` flake input, Ryoku reports the
current source and version but deliberately does not mutate the local checkout.
Update the development checkout manually, then rebuild NixOS as usual.

## NixOS updated will come later than upstream Arch due to new versions requiring the AUR and pacman to update. I aim to update Ryoku on Nix within 7 days of upstream release.

## Repository layout

| Path | One job |
|---|---|
| `ryoku/` | The shared Ryoku desktop: Hyprland configuration, Quickshell shell, lockscreen, app configs, CLI, Hub, services, and brand assets. |
| `nix/` | The NixOS implementation: packages, NixOS module, installer, system bridge, materializer, update integration, and Nix-specific runtime glue. |
| `flake.nix` | The public Nix entrypoint exposing the Ryoku NixOS module, packages, apps, checks, and development environment. |
| `VERSION` | The authoritative version of the NixOS implementation. |
| `docs/` | Documentation and supporting guides shared with or adapted from the wider Ryoku project. |


## Credits and license

Ryoku's alpha series began as a fork of Omarchy, created by David Heinemeier
Hansson and contributors. From the beta series on it was pruned and rebuilt as an
independent project that shares no code with Omarchy. The Ryoku shell is custom,
with its frame-blob rendering and some animations adapted from
the [Caelestia shell](https://github.com/caelestia-dots/shell), and parts of the
display configuration UI adapted from
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell). Full
attribution and upstream links are in [`NOTICE`](NOTICE). Ryoku is released under
the [GNU GPL v3](LICENSE).
</content>
