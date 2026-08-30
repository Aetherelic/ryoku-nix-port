{ pkgs, hyprglass, imgborders }:

pkgs.runCommand "ryoku-hyprland-plugins" {
  nativeBuildInputs = [ pkgs.findutils pkgs.coreutils ];
} ''
  outdir="$out/lib/hyprland/plugins"
  mkdir -p "$outdir"

  install_plugin() {
    out_name="$1"
    package="$2"
    candidate="$(find "$package" -type f -name "*$out_name*.so" -print | head -n 1)"

    if [ -z "$candidate" ]; then
      echo "ryoku-hyprland-plugins: no shared object in $package" >&2
      exit 1
    fi

    ln -s "$candidate" "$outdir/$out_name.so"
  }

  install_plugin dynamic-cursors ${pkgs.hyprlandPlugins.hypr-dynamic-cursors}
  install_plugin hyprbars ${pkgs.hyprlandPlugins.hyprbars}
  install_plugin hyprfocus ${pkgs.hyprlandPlugins.hyprfocus}
  install_plugin imgborders ${imgborders}
  install_plugin hyprglass ${hyprglass}
''
