{ pkgs, src }:

pkgs.stdenv.mkDerivation {
  pname = "ryoku-livewall";
  version = "unstable";

  src = src + "/ryoku/shell/livewall";

  nativeBuildInputs = [
    pkgs.pkg-config

    # Protocol XML -> generated Wayland client bindings.
    # Nixpkgs splits the scanner executable from the Wayland
    # libraries, so the library package alone is insufficient.
    pkgs.wayland-scanner
    pkgs.wayland-protocols
  ];

  buildInputs = [
    pkgs.wayland
    pkgs.ffmpeg
  ];

  buildPhase = ''
    runHook preBuild

    bash ./build.sh ./ryoku-livewall

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 \
      ./ryoku-livewall \
      "$out/bin/ryoku-livewall"

    runHook postInstall
  '';

  meta = {
    description = "Ryoku lightweight Wayland video wallpaper daemon";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
