{ pkgs, src, hyprglassSrc, bibataMaterialSrc, imgbordersSrc }:

let
  qmlRoot = "lib/qt-6/qml";

  shell = import ./ryoku-shell.nix {
    inherit pkgs src;
  };

  cli = import ./ryoku-cli.nix {
    inherit pkgs src;
  };

  hub = import ./ryoku-hub.nix {
    inherit pkgs src;
  };

  rashin = import ./ryoku-rashin.nix {
    inherit pkgs src;
  };

  ryostore = import ./ryoku-ryostore.nix {
    inherit pkgs src;
  };

  ryomotion = import ./ryoku-ryomotion.nix {
    inherit pkgs;
  };

  ryovmHelpers = import ./ryoku-ryovm-helpers.nix {
    inherit pkgs src;
  };

  livewall = import ./ryoku-livewall.nix {
    inherit pkgs src;
  };

  qmkHid = import ./qmk-hid.nix {
    inherit pkgs;
  };

  waifu2x = import ./waifu2x-ncnn-vulkan.nix {
    inherit pkgs;
  };

  desktopData = import ./ryoku-desktop-data.nix {
    inherit pkgs src;
  };

  helpers = import ./ryoku-helpers.nix {
    inherit pkgs src;
  };

  hyprglass = import ./ryoku-hyprglass.nix {
    inherit pkgs;
    src = hyprglassSrc;
  };

  imgborders = pkgs.hyprlandPlugins.imgborders.overrideAttrs (_: {
    pname = "ryoku-imgborders";
    version = "unstable";
    src = imgbordersSrc;
  });

  hyprPlugins = import ./ryoku-hypr-plugins.nix {
    inherit pkgs hyprglass imgborders;
  };

  cursorMaterial = import ./ryoku-cursor-material.nix {
    inherit pkgs;
    ryokuSrc = src;
    bibataSrc = bibataMaterialSrc;
  };

  mapleMonoNF = import ./ryoku-maple-mono-nf.nix {
    inherit pkgs;
  };

  nixosSystemBridge = import ./ryoku-nixos-system-bridge.nix {
    inherit pkgs src;
  };

  blobs = import ./ryoku-blobs.nix {
    inherit pkgs src qmlRoot;
  };

  mkPureQmlModule =
    {
      pname,
      moduleName,
      sourcePath,
      description,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname;

      version = "unstable";
      src = src + sourcePath;

      dontBuild = true;

      installPhase = ''
        runHook preInstall

        dest="$out/${qmlRoot}/Ryoku/${moduleName}"

        mkdir -p "$dest"
        cp -a ./. "$dest/"

        rm -f "$dest/install.sh"

        runHook postInstall
      '';

      meta = {
        inherit description;
        homepage = "https://github.com/neur0map/ryoku-arch";
        license = pkgs.lib.licenses.gpl3Only;
        platforms = [ "x86_64-linux" ];
      };
    };

  ui = mkPureQmlModule {
    pname = "ryoku-ui";
    moduleName = "Ui";
    sourcePath = "/ryoku/ui";
    description = "Shared Ryoku Qt/QML user interface module";
  };

  pluginKit = mkPureQmlModule {
    pname = "ryoku-plugin-kit";
    moduleName = "PluginKit";
    sourcePath = "/ryoku/shell/quickshell/plugins/kit";
    description = "Ryoku shell plugin Qt/QML framework";
  };

  frameBars = mkPureQmlModule {
    pname = "ryoku-framebars";
    moduleName = "FrameBars";
    sourcePath = "/ryoku/shell/framebars";
    description = "Ryoku FrameBars Qt/QML module";
  };

  qml = pkgs.runCommand "ryoku-qml-modules" {
    meta = {
      description = "Combined Ryoku Qt/QML module tree";
      homepage = "https://github.com/neur0map/ryoku-arch";
      license = pkgs.lib.licenses.gpl3Only;
      platforms = [ "x86_64-linux" ];
    };
  } ''
    mkdir -p "$out/${qmlRoot}/Ryoku"

    cp -a \
      ${ui}/${qmlRoot}/Ryoku/Ui \
      "$out/${qmlRoot}/Ryoku/Ui"

    cp -a \
      ${pluginKit}/${qmlRoot}/Ryoku/PluginKit \
      "$out/${qmlRoot}/Ryoku/PluginKit"

    cp -a \
      ${frameBars}/${qmlRoot}/Ryoku/FrameBars \
      "$out/${qmlRoot}/Ryoku/FrameBars"

    cp -a \
      ${blobs}/${qmlRoot}/Ryoku/Blobs \
      "$out/${qmlRoot}/Ryoku/Blobs"
  '';

  bundle = pkgs.symlinkJoin {
    name = "ryoku-desktop-bundle";

    meta = {
      description = "Complete Ryoku desktop runtime bundle";
      homepage = "https://github.com/neur0map/ryoku-arch";
      license = pkgs.lib.licenses.gpl3Only;
      platforms = [ "x86_64-linux" ];
    };

    paths = [
      shell
      cli
      hub
      rashin
      ryostore
      ryomotion
      ryovmHelpers
      livewall
      qmkHid
      waifu2x
      desktopData
      helpers
      nixosSystemBridge
      qml
    ];
  };
in
{
  inherit
    shell
    cli
    hub
    rashin
    ryostore
    ryomotion
    ryovmHelpers
    livewall
    qmkHid
    waifu2x
    desktopData
    helpers
    nixosSystemBridge
    hyprglass
    imgborders
    hyprPlugins
    cursorMaterial
    mapleMonoNF

    ui
    pluginKit
    frameBars
    blobs
    qml

    bundle
    ;
}
