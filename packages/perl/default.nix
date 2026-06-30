{
  perl,
  writeText,
}:

let
  # Linux: the fully-static musl-cross perl (the `perl` injected by the flake's
  # pkgsStatic callPackage), like every other Linux tool here. The static build
  # has no dylib so no install-name rewriting is needed (see ./darwin.nix for
  # the macOS counterpart).
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    export PERL5LIB=$root/lib/perl5:$PERL5LIB
    for d in "$root"/lib/perl5/site_perl/*/; do
      [ -d "$d" ] && PERL5LIB=$d:$PERL5LIB
    done
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
