{ pkgs, ryokuSrc, bibataSrc }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "ryoku-cursor-material";
  version = "1.0.0";

  src = ryokuSrc;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    data="$out/share/ryoku-cursor-material/bibata"
    mkdir -p "$data" "$out/bin"

    cp -a ${bibataSrc}/src "$data/src"
    cp -a ${bibataSrc}/svg "$data/svg"
    cp -a ${bibataSrc}/config "$data/config"

    install -Dm755 \
      release/packages/ryoku-cursor-material/ryoku-cursor-material-recolor \
      "$out/bin/ryoku-cursor-material-recolor"

    substituteInPlace "$out/bin/ryoku-cursor-material-recolor" \
      --replace-fail \
        '/usr/share/ryoku-cursor-material/bibata' \
        "$data"

    wrapProgram "$out/bin/ryoku-cursor-material-recolor" \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.python3
        pkgs.librsvg
        pkgs.xcursorgen
        pkgs.hyprland
      ]}

    runHook postInstall
  '';

  meta = {
    description = "Ryoku wallpaper-accent Material Bibata cursor helper";
    homepage = "https://github.com/SakibShahariar/material-bibata-cursor";
    license = with pkgs.lib.licenses; [ gpl3Plus mit ];
    platforms = pkgs.lib.platforms.linux;
  };
}
