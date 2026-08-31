{ pkgs }:

let
  rev = "8f02fe5e34e27dc60260ee564e86a11f2dc7ca87";

  src = pkgs.fetchzip {
    url = "https://github.com/FrameworkComputer/qmk_hid/archive/${rev}.tar.gz";
    hash = "sha256-GuI/hDqMEpJ5Flcs4hRXZr3pbVFreelJIlS/idViHmY=";
  };
in
pkgs.rustPlatform.buildRustPackage {
  pname = "qmk-hid";
  version = "0.1.13";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  # Upstream 0.1.13 has a broken doctest for its private format_bcd helper.
  # Keep the regular Rust test targets while excluding documentation tests.
  cargoTestFlags = [
    "--tests"
  ];

  nativeBuildInputs = [
    pkgs.pkg-config
  ];

  buildInputs = [
    pkgs.systemd
  ];

  meta = {
    description = "Command-line tool for interacting with QMK devices over HID";
    homepage = "https://github.com/FrameworkComputer/qmk_hid";
    license = pkgs.lib.licenses.bsd3;
    platforms = pkgs.lib.platforms.linux;
    mainProgram = "qmk_hid";
  };
}
