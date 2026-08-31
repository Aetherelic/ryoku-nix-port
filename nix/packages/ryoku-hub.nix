{ pkgs, src }:

pkgs.stdenv.mkDerivation {
  pname = "ryoku-hub";
  version = "unstable";

  src = src + "/ryoku/hub/backend";

  nativeBuildInputs = [
    pkgs.go
  ];

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"
    export GOCACHE="$TMPDIR/go-cache"
    export GOTOOLCHAIN=local

    go build \
      -mod=vendor \
      -trimpath \
      -o ryoku-hub \
      .

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    install -Dm755 ryoku-hub "$out/bin/ryoku-hub"

    runHook postInstall
  '';
  meta = {
    description = "Ryoku Settings and Hub backend";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };

}
