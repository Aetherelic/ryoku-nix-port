<div align="center">

# Ryoku on NixOS ❄️

### Native NixOS packaging and platform integration for Ryoku

An experimental NixOS port of
[neur0map/ryoku-arch](https://github.com/neur0map/ryoku-arch).

**Current status: late-stage development / hardware validation**

![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?logo=nixos&logoColor=white)
![Ryoku](https://img.shields.io/badge/Ryoku-0.45.7--beta.18-7c6f93)
![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-58c7f3)
![Status](https://img.shields.io/badge/Port-Experimental-orange)

</div>

---

## About this port

This branch ports the current Ryoku desktop from its Arch-oriented deployment
model to NixOS while preserving Ryoku itself as closely as possible.

The goal is **not** to run the Arch installer inside NixOS or reproduce Arch
filesystem mutations with shell scripts.

Instead, Arch-specific system operations are translated into native NixOS
concepts:

- Nix packages instead of pacman/AUR packages
- NixOS modules instead of imperative system configuration
- systemd units owned declaratively by NixOS
- immutable packaged resources separated from writable runtime state
- Nix-safe bridges for operations which genuinely require runtime privilege
- upstream behaviour preserved outside NixOS wherever possible

The result is intended to eventually become an officially maintainable NixOS
platform implementation of Ryoku.

---

## Current base

The initial NixOS port was developed against:

```text
Ryoku upstream branch:  unstable-dev
Upstream revision:      e57d11c09
Ryoku release:          0.45.7-beta.18
Initial Nix checkpoint: 2957cf765
```

NixOS currently tracks `nixos-unstable`.

---

# Screenshots

> Screenshots in this section are from the native NixOS port running on real
> hardware, not an Arch VM.

## Desktop

<p align="center">
  <img src="docs/screenshots/desktop.png" width="900" alt="Ryoku desktop running on NixOS">
</p>

## Ryoku Hub

<p align="center">
  <img src="docs/screenshots/hub.png" width="900" alt="Ryoku Hub running on NixOS">
</p>

## RyoStore

<p align="center">
  <img src="docs/screenshots/ryostore.png" width="900" alt="RyoStore running on NixOS">
</p>

## qylock

<p align="center">
  <img src="docs/screenshots/lockscreen.png" width="900" alt="Ryoku qylock running on NixOS">
</p>

## Custom RyoStore lockscreen

<p align="center">
  <img src="docs/screenshots/custom-lockscreen.png" width="900" alt="Custom RyoStore lockscreen running on NixOS">
</p>

## Ryo Motion

<p align="center">
  <img src="docs/screenshots/ryomotion.png" width="900" alt="Ryo Motion running on NixOS">
</p>

---

# Port status

## Core desktop

- [x] Ryoku shell builds on NixOS
- [x] Ryoku shell runs natively under Hyprland
- [x] Ryoku QML modules packaged
- [x] Ryoku UI packaged
- [x] PluginKit packaged
- [x] FrameBars packaged
- [x] Blobs Qt/QML plugin packaged
- [x] Hyprland Ryoku session materialized
- [x] Ryoku IPC daemon packaged
- [x] Declarative `ryoku-shell.service`
- [x] Runtime PATH and QML environment integrated
- [x] NixOS platform bridge exposed to Ryoku
- [x] Shell autostart
- [x] Shell keybinds
- [x] Multi-monitor operation
- [ ] Shell child-process lifecycle cleanup
- [ ] Final long-running memory/resource validation

### Known issue

`ryoku-shell.service` currently allows some spawned applications/processes to
remain associated with its systemd cgroup after service restarts.

This has produced unusually high service accounting, including a measured
memory peak of approximately **5 GiB**.

This is the next major runtime issue scheduled for investigation.

---

## Nix packaging

- [x] Flake interface
- [x] NixOS module
- [x] Ryoku CLI
- [x] Ryoku Shell
- [x] Ryoku Hub
- [x] RyoStore
- [x] Rashin
- [x] RyoVM helpers
- [x] Livewall
- [x] Ryoku UI
- [x] PluginKit
- [x] FrameBars
- [x] Blobs QML plugin
- [x] Desktop data
- [x] Runtime helper scripts
- [x] NixOS system bridge
- [x] `waifu2x-ncnn-vulkan`
- [x] Ryo Motion
- [x] Development runner
- [x] User configuration materializer
- [x] Flake checks for packaged components
- [ ] Complete package/runtime parity audit
- [ ] Clean-machine installation validation

Current Nix-specific structure:

```text
nix/
├── apps/
├── bridge/
├── modules/
├── packages/
└── shell/
```

---

## Configuration materialization

Ryoku upstream expects a writable user configuration tree.

The NixOS port separates immutable packaged resources from mutable user and
runtime state:

```text
/nix/store/...
      │
      ▼
Ryoku materializer
      │
      ├── ~/.config/...
      ├── ~/.local/share/...
      └── ~/.local/state/...
```

- [x] Base Ryoku configuration packaged immutably
- [x] User configuration materialized automatically
- [x] Runtime-generated Matugen files remain writable
- [x] Existing user-owned runtime state preserved where appropriate
- [x] Materializer integrated with systemd
- [x] Materializer refreshes when its Nix derivation changes

---

## Themes and Matugen

- [x] Wallpaper switching
- [x] Matugen palette generation
- [x] Kitty colours
- [x] btop colours
- [x] Qt6 colour output
- [x] Ryoku shell theme updates
- [x] Writable generated theme outputs
- [x] Theme persistence
- [ ] Final peripheral theming parity audit

---

## Ryoku Hub

- [x] Hub builds and launches
- [x] NixOS environment detection
- [x] Connections page compatibility work
- [x] Profile/system information compatibility
- [x] Update UI compatibility work
- [x] Lockscreen page
- [x] Nix-safe PAM UI guard
- [x] Nix-safe SDDM theme switching
- [x] Arch behaviour retained outside the Nix bridge
- [ ] Full page-by-page parity test

### PAM safety

Upstream Ryoku can directly modify PAM files for optional fingerprint
integration.

On NixOS:

```text
/etc/pam.d/*
```

is declaratively owned system configuration.

When:

```text
RYOKU_NIX_SYSTEM_BRIDGE=1
```

Ryoku therefore refuses to imperatively modify the PAM configuration for:

- `sudo`
- SDDM
- polkit/admin prompts

The original Arch behaviour remains unchanged outside the NixOS bridge.

---

## qylock / Lockscreen

- [x] qylock deployed
- [x] Quickshell lock client
- [x] Wayland session-lock protocol
- [x] Password authentication
- [x] Wrong-password rejection
- [x] Successful unlock
- [x] Lock marker lifecycle
- [x] Locker process cleanup
- [x] NixOS-compatible private PAM stack
- [x] Arch-only fingerprint PAM dependency removed
- [x] Secure private PAM fallback
- [x] Orbital fallback theme
- [x] RyoStore custom lockscreen discovery
- [x] RyoStore custom lockscreen installation
- [x] RyoStore custom lockscreen activation
- [x] Custom qylock themes tested
- [x] Hypridle pre-suspend locking

The bundled Arch-oriented PAM stack is replaced during materialization with a
NixOS-compatible private stack rather than modifying `/etc/pam.d`.

---

## SDDM

- [x] Ryoku SDDM theme packaged
- [x] Required Qt6 dependencies
- [x] `sddm-greeter-qt6 --test-mode`
- [x] Orbital theme rendering
- [x] Dynamic custom RyoStore themes
- [x] Nix-safe mutable SDDM theme bridge
- [x] `/usr/share` remains Nix-owned
- [x] `/etc/sddm.conf.d` remains Nix-owned
- [x] Runtime theme payload stored under `/var/lib/ryoku`
- [ ] Final real login validation after a fresh boot/session

Dynamic theme flow:

```text
RyoStore
   │
   ▼
~/.local/share/qylock/themes
   │
   ▼
Ryoku Hub
   ├──────────────► ~/.config/qylock/theme
   │                    │
   │                    └── qylock
   │
   └──► Nix bridge
             │
             ▼
      /var/lib/ryoku/sddm-theme
             │
             ▼
            SDDM
```

---

## Hypridle

- [x] Hypridle packaged
- [x] Ryoku configuration deployed
- [x] Declarative user service
- [x] Starts with the Hyprland session
- [x] Desktop systems supported
- [x] Laptop behaviour retained
- [x] Lock-before-suspend confirmed
- [x] DPMS rules loaded

Upstream's helper intentionally starts Hypridle only on laptop hardware.

The NixOS implementation instead owns Hypridle through a user systemd unit,
allowing Ryoku's AC/desktop timeout rules to work on desktop systems too.

---

## NVIDIA suspend / resume

- [x] Suspend failure diagnosed
- [x] qylock ruled out as the primary cause
- [x] Hyprland crash traced to NVIDIA resume failure
- [x] `NVreg_PreserveVideoMemoryAllocations=1` configured
- [x] `NVreg_UseKernelSuspendNotifiers=1` configured
- [x] Temporary video-memory storage path configured
- [x] Updated NixOS generation builds successfully
- [ ] Reboot into updated NVIDIA kernel-module configuration
- [ ] Verify live NVIDIA parameters
- [ ] Final suspend/resume test
- [ ] Confirm no NVIDIA Xid 13/31/154 errors after resume

The corrected NVIDIA configuration is already present in the next system
generation, but final validation requires loading the rebuilt kernel module
after reboot.

---

## RyoStore

- [x] RyoStore backend builds
- [x] RyoStore UI launches
- [x] Product catalogue
- [x] Installation transactions
- [x] Lockscreen packages
- [x] Lock themes installed into XDG user data
- [x] Custom lockscreen tested
- [x] RyoStore-installed themes survive Ryoku materialization
- [ ] Full category-by-category delivery audit
- [ ] Remove remaining Arch-only assumptions where found

---

## Ryo Motion

- [x] Ryo Motion packaged
- [x] Upstream source pinned
- [x] Required npm runtime packaged
- [x] Electron runtime
- [x] Native Wayland launch
- [x] Hyprland integration
- [x] Global executable
- [x] Basic recording
- [x] Studio recording
- [x] Cursor telemetry sidecar generation
- [x] CPU recording fallback for unsupported NVIDIA NVENC API
- [ ] Final launch-from-Ryoku-UI test
- [ ] Floating Studio controls final test
- [ ] Edit-after-quick-recording test
- [ ] Cursor-follow / automatic zoom final UI validation

---

# NixOS integration

The intended public interface is deliberately small:

```nix
{
  inputs.ryoku.url = "github:OWNER/REPOSITORY";

  outputs = { nixpkgs, ryoku, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./configuration.nix
        ryoku.nixosModules.default

        {
          programs.ryoku.enable = true;
        }
      ];
    };
  };
}
```

The module owns the packages, services, environment and runtime materialization
required by Ryoku.

This interface is still under development and should not yet be considered
stable.

---

# Platform compatibility strategy

The NixOS port attempts to keep modifications to upstream Ryoku as small as
possible.

Most Nix-specific implementation lives under:

```text
nix/
```

Where application code genuinely requires platform-specific behaviour, the port
currently uses:

```text
RYOKU_NIX_SYSTEM_BRIDGE=1
```

to select Nix-safe behaviour while retaining the original Arch path.

Current compatibility touchpoints include:

- SDDM theme activation
- PAM controls
- Hypridle startup
- network/system operations
- filesystem and runtime integration

Long term, these hooks could be generalized into a formal Ryoku platform
abstraction.

---

# Upstream maintenance model

Ryoku Arch remains the upstream and fastest-moving implementation.

The proposed NixOS maintenance flow is:

```text
Ryoku upstream release
        │
        ▼
sync into Nix development branch
        │
        ▼
package / compatibility updates
        │
        ▼
Nix checks + VM testing
        │
        ▼
real hardware validation
        │
        ▼
NixOS release
```

The intention is for the NixOS version to follow the equivalent upstream Ryoku
release after a short validation period rather than intentionally staying
multiple versions behind.

---

# Remaining work

Before considering the port release-ready:

- [ ] Fix `ryoku-shell.service` child-process lifecycle/resource accounting
- [ ] Complete Hub page-by-page parity validation
- [ ] Complete RyoStore category delivery audit
- [ ] Complete remaining peripheral integration audit
- [ ] Reboot and validate NVIDIA suspend/resume fix
- [ ] Validate real SDDM authentication/login
- [ ] Complete remaining Ryo Motion UI tests
- [ ] Clean-machine / VM deployment test
- [ ] Reduce and document upstream compatibility touchpoints
- [ ] Add Nix-specific regression tests
- [ ] Document upstream sync/maintenance workflow
- [ ] Test fresh clone → enable module → functional Ryoku desktop

---

# Not yet a release

This repository is currently intended for development and review.

It has been tested on a real NixOS + Hyprland installation, but the port has not
yet completed clean-machine validation and should **not** currently be treated
as a production-ready NixOS distribution or installer.

A future Ryoku NixOS ISO is planned separately once the desktop port is stable.

---

# Credits

Ryoku itself is developed by
[neur0map](https://github.com/neur0map) and contributors.

This repository contains ongoing NixOS platform work for the upstream Ryoku
project.

Upstream repository:

**https://github.com/neur0map/ryoku-arch**

---

<div align="center">

### Ryoku, declaratively. ❄️

</div>
