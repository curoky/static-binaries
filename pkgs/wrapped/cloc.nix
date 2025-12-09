{ lib, cloc, perl, perlPackages, rsync, writeText}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    store=$root/..

    export PERL5LIB=$root/lib/perl5/site_perl
    if [[ -f $store/perl/bin/perl ]]; then
      exec -a "$0" $store/perl/bin/perl "$root/bin/_cloc" "$@"
    else
      exec -a "$0" "$root/bin/_cloc" "$@"
    fi
  '';
in

cloc.overrideAttrs (oldAttrs: rec {
  nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ perl rsync];
  postFixup = "";
  postInstall = ''
    chmod +w $out/bin/
    mv $out/bin/cloc $out/bin/_cloc
    cp ${wrapperScript} $out/bin/cloc
    chmod +x $out/bin/cloc

    mkdir -p $out/lib/perl5
    rsync -a ${perlPackages.Moo}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.AlgorithmDiff}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.RoleTiny}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.SubQuote}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.ParallelForkManager}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.RegexpCommon}/lib/perl5/ $out/lib/perl5/
  '';
})
