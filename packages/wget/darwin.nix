{
  stdenv,
  fetchurl,
  wget,
  pkgsStatic,
  writeText,
}:

let
  # macOS: there is no static libc, so wget cannot be fully static. Build the
  # *native* wget (prebuilt in the upstream cache, no local toolchain build) but
  # swap each of its non-system dynamic dependencies for the matching
  # `pkgsStatic` archive (.a) so the linker embeds them statically, leaving wget
  # depending only on /usr/lib system libs and the macOS frameworks. This mirrors
  # the darwin portability ladder (DESIGN.md strategy 2): every nix dependency
  # linked statically, only system libraries stay dynamic. On Linux wget is built
  # from the fully-static `pkgsStatic` set instead (see ./default.nix).
  wget_static = wget.override {
    libidn2 = pkgsStatic.libidn2;
    zlib = pkgsStatic.zlib;
    pcre2 = pkgsStatic.pcre2;
    libuuid = pkgsStatic.libuuid;
    libiconv = pkgsStatic.libiconv;
    libintl = pkgsStatic.libintl;
    openssl = pkgsStatic.openssl;
  };

  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_wget" --ca-certificate $root/etc/ssl/certs/ca-certificates.crt "$@"
  '';
in

stdenv.mkDerivation rec {
  pname = "wget";
  version = "1.0.0";

  src = fetchurl {
    url = "https://curl.se/ca/cacert-2024-09-24.pem";
    sha256 = "sha256-GJ089tEDGF+6BtdsGvkVJjxtQiJUgaF1noU7M6yFdUA=";
  };

  unpackPhase = ":";

  installPhase = ''
    mkdir -p $out
    cp -r ${wget_static}/bin $out/bin
    cp -r ${wget_static}/etc $out/etc

    chmod +w $out/etc/
    mkdir -p $out/etc/ssl/certs/
    cp ${src} $out/etc/ssl/certs/ca-certificates.crt

    chmod +w $out/bin/
    mv $out/bin/wget $out/bin/_wget
    cp ${wrapperScript} $out/bin/wget
    chmod +x $out/bin/wget
  '';
}
