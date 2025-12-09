{ lib, stdenv, fetchurl, perl, writeText}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    
    export PERL5LIB=$root/lib/perl5:$PERL5LIB

    exec -a "$0" "$root/bin/_perl" "$@"
  '';
in

perl.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/perl $out/bin/_perl
    cp ${wrapperScript} $out/bin/perl
    chmod +x $out/bin/perl
  '';
})
