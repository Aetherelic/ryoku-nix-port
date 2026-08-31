{ pkgs }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "ryoku-maple-mono-nf";
  version = "7.9";

  src = pkgs.fetchurl {
    url = "https://github.com/subframe7536/maple-font/releases/download/v${version}/MapleMono-NF.zip";
    hash = "sha256-WQmLh8iV2HFjXTdoDogACuKysltVQoGVsijsWJ41+4k=";
  };

  nativeBuildInputs = [ pkgs.unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src" -d source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/fonts/truetype"
    find source -type f -name '*.ttf' -exec cp -v {} "$out/share/fonts/truetype/" \;
    runHook postInstall
  '';

  meta = {
    description = "Maple Mono NF used by the Ryoku terminal/code font picker";
    homepage = "https://github.com/subframe7536/maple-font";
    license = pkgs.lib.licenses.ofl;
    platforms = pkgs.lib.platforms.all;
  };
}
