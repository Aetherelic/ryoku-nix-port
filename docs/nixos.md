# NixOS

Ryoku's canonical distribution is Arch Linux, but the Ryoku desktop can also be deployed on an existing NixOS system through this repository's flake and NixOS module.

The NixOS integration packages the Ryoku shell, Hub, QML modules, desktop configuration and helper tools. It does not reproduce Arch-specific system management such as pacman, the AUR, mkinitcpio or Limine.

## Status

The NixOS port currently targets:

- `x86_64-linux`
- a recent NixOS system with flakes enabled
- Hyprland on Wayland

Development and validation are performed against `nixos-unstable`.

The module manages Ryoku's desktop dependencies and user services, but it does not repartition the machine or replace the host's bootloader, kernel, graphics-driver configuration or existing NixOS system definition.

## Add Ryoku to a NixOS flake

Add Ryoku as an input:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    ryoku = {
      url = "github:neur0map/ryoku-arch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

Import the module and enable Ryoku:

```nix
{
  outputs = { nixpkgs, ryoku, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ryoku.nixosModules.default

        {
          programs.ryoku.enable = true;
        }
      ];
    };
  };
}
```

Replace `my-host` with the name of your own NixOS configuration.

## Build and deploy

Apply the system configuration:

```bash
sudo nixos-rebuild switch --flake .#my-host
```

After the first successful rebuild, materialize the user-facing Ryoku configuration:

```bash
ryoku-materialize
```

The first materialization preserves existing configuration and Ryoku QML data under:

```text
~/.local/state/ryoku/nix/backups/
```

The original backup path is recorded in:

```text
~/.local/state/ryoku/nix/initial-backup-path
```

Log out after the first materialization and start the Hyprland session.

## What the NixOS module owns

The module manages the machine-facing Ryoku integration, including:

- Ryoku packages and runtime command dependencies
- Hyprland and XDG portal integration
- PipeWire and WirePlumber
- NetworkManager
- Bluetooth
- polkit and GNOME Keyring
- power-profile and power-information services
- required fonts
- `hyprland-session.target`
- `ryoku-shell.service`
- `ryoku-ai-usage.service`
- `ryoku-ai-usage.timer`

Ryoku-owned systemd units are defined declaratively on NixOS instead of being copied into `~/.config/systemd/user`. This avoids user-local Arch units shadowing the NixOS definitions.

## Session environment

The NixOS deployment imports the live Hyprland session environment into the systemd user manager. The Ryoku shell waits for a valid Wayland socket before starting, so values such as `WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE` come from the active compositor session.

Do not add a second manual Ryoku shell `exec-once` when using the module.

## Package counts

On NixOS the Hub displays:

```text
SYSTEM · USER · TOTAL
```

`SYSTEM` counts direct packages in `environment.systemPackages`.

`USER` counts packages installed through the user's imperative `nix profile`.

The full Nix store closure is deliberately not used because it includes transitive dependencies rather than only packages the user selected.

Arch keeps its existing explicit/AUR package display.

## Updating

Installed Ryoku systems update through the Ryoku CLI:

    ryoku update

On NixOS this uses Ryoku's Nix-specific update backend. It updates only the
configured Ryoku flake input, builds the resulting NixOS system, and switches to
the new generation.

The Arch package transaction path is not used on NixOS. Systems using a local
`path:` Ryoku input are intentionally not modified automatically; update the
development checkout manually and rebuild the host flake instead.

## Development

The flake also exposes:

```bash
nix run .#ryoku-dev
nix develop
```

The development runner is for working directly from a Ryoku checkout. Normal installed systems should use the NixOS module and systemd-managed shell.

## Arch and NixOS

The goal of the NixOS port is desktop feature parity, not to make NixOS impersonate Arch Linux.

On NixOS:

- packages come from Nix rather than pacman or the AUR
- services are expressed through NixOS modules
- Ryoku does not manage mkinitcpio
- Ryoku does not install or configure Limine
- Ryoku does not replace the host bootloader
- Ryoku does not repartition disks
- the host keeps its existing kernel and graphics-driver policy
- NixOS generations remain the system rollback mechanism

## One-command installation

For an existing flake-based NixOS system:

~~~bash
nix run github:Aetherelic/Ryoku-on-NixOS/main#install
~~~

The installer detects the NixOS host, backs up the existing flake configuration,
adds the Ryoku module, builds the new generation before switching, and
materializes the desktop after a successful switch.

It does not modify bootloader, kernel, disk, or partition settings.

For a non-default flake or multi-host configuration:

~~~bash
nix run github:Aetherelic/Ryoku-on-NixOS/main#install -- \
  --flake /path/to/nixos#hostname
~~~

Use `--dry-run` to inspect the proposed configuration without changing files.
