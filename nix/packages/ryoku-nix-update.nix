{ pkgs, src }:

pkgs.writeShellApplication {
  name = "ryoku-nix-update";

  runtimeInputs = with pkgs; [
    coreutils
    curl
    git
    gnugrep
    gnused
    jq
    nix
    nixos-rebuild
    sudo
  ];

  text =
    builtins.readFile
      (src + "/nix/scripts/ryoku-nix-update");
}
