{
  lib,
  stdenv,
  python3,
  fetchurl,
  fetchFromGitHub,
  cmake,
  fetchzip,
  opencc,
  unzip,
  python3Packages,
  pkgs,
}:

stdenv.mkDerivation rec {
  pname = "cacert";
  version = "2024-09-24";

  src = fetchurl {
    url = "https://curl.se/ca/cacert-${version}.pem";
    sha256 = "sha256-GJ089tEDGF+6BtdsGvkVJjxtQiJUgaF1noU7M6yFdUA=";
  };

  unpackPhase = ":";

  installPhase = ''
    mkdir -p $out/etc/ssl/certs
    cp ${src} $out/etc/ssl/certs/ca-certificates.crt
  '';

  meta = with lib; {
    description = "CA certificates in PEM format from curl.se";
  };
}
