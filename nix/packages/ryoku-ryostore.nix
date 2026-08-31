{ pkgs, src }:

pkgs.stdenv.mkDerivation {
  pname = "ryoku-ryostore";
  version = "unstable";

  src = src + "/ryoku/apps/ryostore/backend";

  nativeBuildInputs = [
    pkgs.go
  ];

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"
    export GOCACHE="$TMPDIR/go-cache"
    export GOTOOLCHAIN=local

    go build \
      -trimpath \
      -o ryostore \
      .

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"

    install -Dm755 \
      ryostore \
      "$out/bin/ryostore"

    runHook postInstall
  '';

  meta = {
    description = "RyoStore catalogue and installation backend";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
