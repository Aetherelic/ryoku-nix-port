{ pkgs, src }:

pkgs.stdenv.mkDerivation {
  pname = "ryoku-cli";
  version = "unstable";

  src = src + "/ryoku/cli";

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
      -o ryoku \
      .

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    install -Dm755 ryoku "$out/bin/ryoku"

    runHook postInstall
  '';
  meta = {
    description = "Ryoku desktop command-line control utility";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };

}
