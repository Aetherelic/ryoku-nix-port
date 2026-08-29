{ pkgs, src }:

let
  repoSrc = src;
in
pkgs.stdenv.mkDerivation {
  pname = "ryoku-rashin";
  version = "unstable";

  src = repoSrc + "/ryoku/rashin/backend";

  nativeBuildInputs = [
    pkgs.go
  ];

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"
    export GOCACHE="$TMPDIR/go-cache"
    export GOTOOLCHAIN=local
    export CGO_ENABLED=0

    go build \
      -mod=vendor \
      -trimpath \
      -o ryoku-rashin \
      .

    ./ryoku-rashin \
      repo-index \
      "${repoSrc}" \
      "$TMPDIR/ryoku-repo.md"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p \
      "$out/bin" \
      "$out/share/ryoku/rashin"

    install -Dm755 \
      ryoku-rashin \
      "$out/bin/ryoku-rashin"

    ln -s \
      ryoku-rashin \
      "$out/bin/rashin"

    install -Dm644 \
      "$TMPDIR/ryoku-repo.md" \
      "$out/share/ryoku/rashin/ryoku-repo.md"

    runHook postInstall
  '';

  meta = {
    description = "Ryoku Rashin local agent OS daemon and dashboard";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
