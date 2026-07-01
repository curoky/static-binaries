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
  version = "2026-05-14";

  src = fetchurl {
    url = "https://curl.se/ca/cacert-${version}.pem";
    sha256 = "sha256-hqHzNmr6x8b4rp88d5rCIRKTKMQ/CrK4gX6y82KlAlw=";
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
