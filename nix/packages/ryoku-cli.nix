{ pkgs, src, version }:

pkgs.stdenv.mkDerivation {
  pname = "ryoku-cli";
  inherit version;

  src = src + "/ryoku/cli";

  nativeBuildInputs = [
    pkgs.go
    pkgs.makeWrapper
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

    install -Dm755 \
      ryoku \
      "$out/bin/.ryoku-wrapped"

    makeWrapper \
      "$out/bin/.ryoku-wrapped" \
      "$out/bin/ryoku" \
      --set RYOKU_UPDATE_BACKEND nix \
      --set RYOKU_NIX_VERSION "${version}" \
      --set RYOKU_NIX_CHANNEL nix

    runHook postInstall
  '';

  meta = {
    description = "Ryoku desktop command-line control utility";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
