{ pkgs, src }:

let
  goTool =
    if builtins.hasAttr "go_1_26" pkgs
    then pkgs.go_1_26
    else pkgs.go;
in
pkgs.stdenv.mkDerivation {
  pname = "ryoku-ryovm-helpers";
  version = "unstable";

  src = src + "/ryoku/apps/ryovm";

  nativeBuildInputs = [
    goTool
  ];

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"
    export GOCACHE="$TMPDIR/go-cache"
    export GOTOOLCHAIN=local
    export CGO_ENABLED=0

    build_helper() {
      local dir="$1"
      local name="$2"

      (
        cd "$dir"

        go build \
          -trimpath \
          -o "$TMPDIR/$name" \
          .
      )
    }

    build_helper fetch  ryovm-fetch
    build_helper mon    ryovm-mon
    build_helper remote ryossh

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"

    for name in \
      ryovm-fetch \
      ryovm-mon \
      ryossh
    do
      install -Dm755 \
        "$TMPDIR/$name" \
        "$out/bin/$name"
    done

    runHook postInstall
  '';

  meta = {
    description = "Compiled helper backends for Ryoku Ryoport";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
