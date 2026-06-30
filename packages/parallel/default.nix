{
  lib,
  parallel,
  perl,
  writeText,
}:

let
  # Wrapper for the bundled perl scripts. At deploy time it runs the real
  # script (renamed `_<name>`) under the sibling `perl` package, falling back
  # to a system perl. The script's own directory is prepended to PATH so the
  # scripts that shell out to a bare `parallel` (e.g. parsort) find the wrapped
  # one next to them.
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    bindir=$(cd "$(dirname "$script_path")" && pwd)
    store=$bindir/../..

    name=$(basename "$0")
    export PATH=$bindir:$PATH
    exec -a "$0" $store/perl/bin/perl "$bindir/_$name" "$@"
  '';
in

parallel.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ perl ];
  postInstall = (oldAttrs.postInstall or "") + ''
    # The main program ships as `.parallel-wrapped` (the real perl script) plus a
    # nixpkgs bash PATH-wrapper named `parallel`. Drop that wrapper and treat the
    # real script like the others.
    mv $out/bin/.parallel-wrapped $out/bin/parallel
    rm -f $out/bin/sem
    chmod +w $out/bin

    # `sem` is the same script as `parallel`, selected via $0. Give it its own
    # `_sem` (a symlink to `_parallel`) so the wrapper needs no special-casing.
    ln -s _parallel $out/bin/_sem

    # Re-wrap every bundled perl command to run under a sibling/system perl.
    for name in parallel sem niceload parcat parsort sql; do
      [ -e $out/bin/_$name ] || mv $out/bin/$name $out/bin/_$name
      cp ${wrapperScript} $out/bin/$name
      chmod +x $out/bin/$name
    done
  '';
})
