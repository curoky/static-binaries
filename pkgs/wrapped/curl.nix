{
  lib,
  stdenv,
  fetchurl,
  curl,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_curl" --cacert $root/etc/ssl/certs/ca-certificates.crt "$@"
  '';
in

stdenv.mkDerivation rec {
  pname = "curl";
  version = "1.0.0";

  src = fetchurl {
    url = "https://curl.se/ca/cacert-2024-09-24.pem";
    sha256 = "sha256-GJ089tEDGF+6BtdsGvkVJjxtQiJUgaF1noU7M6yFdUA=";
  };

  unpackPhase = ":";

  nativeBuildInputs = [ curl ];

  installPhase = ''
    mkdir -p $out
    cp -r ${curl.bin}/bin/ $out/bin
    cp -r ${curl.dev}/share $out/share

    mkdir -p $out/etc/ssl/certs/
    cp ${src} $out/etc/ssl/certs/ca-certificates.crt

    chmod +w $out/bin/
    mv $out/bin/curl $out/bin/_curl
    cp ${wrapperScript} $out/bin/curl
    chmod +x $out/bin/curl
  '';
}
