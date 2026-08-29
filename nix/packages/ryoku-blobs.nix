{ pkgs, src, qmlRoot }:

pkgs.stdenv.mkDerivation {
  pname = "ryoku-blobs";
  version = "unstable";

  dontWrapQtApps = true;

  src = src + "/ryoku/shell/plugin";

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.qt6.qtshadertools
  ];

  buildInputs = [
    pkgs.qt6.qtbase
    pkgs.qt6.qtdeclarative
    pkgs.qt6.qtmultimedia
    pkgs.qt6.qtshadertools
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/${qmlRoot}/Ryoku"

    cp -a \
      qml/Ryoku/Blobs \
      "$out/${qmlRoot}/Ryoku/Blobs"

    rm -f "$out/${qmlRoot}/Ryoku/Blobs/"*.qrc

    runHook postInstall
  '';

  meta = {
    description = "Ryoku.Blobs Qt/QML metaball rendering module";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
