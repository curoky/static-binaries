{
  stdenv,
  fetchurl,
  wget,
  perlPackages,
  writeText,
}:

let
  # macOS, `pkgsStatic` route. Unlike ./darwin.nix (which builds native pkgs.wget
  # and swaps each non-system dep for its pkgsStatic archive), this variant takes
  # the fully-static `pkgsStatic.wget` directly — same set used on Linux — and
  # only overrides its *build-time* perl. The darwin `pkgsStatic.perl`
  # (perl-static) fails to build: its final `mktables` step runs the freshly
  # built static miniperl to generate the Unicode tables and that static miniperl
  # crashes on darwin (the static build disables most locale support:
  # -DNO_THREAD_SAFE_QUERYLOCALE / -DNO_POSIX_2008_LOCALE / -DNO_LOCALE_COLLATE),
  # exiting with code 2 right after "Updating 'mktables.lst'". wget only needs
  # perl as a build tool, so pointing `perlPackages` at the native (cache-prebuilt)
  # set sidesteps the broken static perl while the wget binary itself still links
  # every nix dep statically — leaving only /usr/lib system libs dynamic. On Linux
  # wget builds straight from pkgsStatic (see ./linux.nix); this is the macOS
  # equivalent with that single build-tool tweak.
  wget_static = wget.override {
    inherit perlPackages;
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
    url = "https://curl.se/ca/cacert-2026-05-14.pem";
    sha256 = "sha256-hqHzNmr6x8b4rp88d5rCIRKTKMQ/CrK4gX6y82KlAlw=";
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
