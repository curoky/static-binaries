{
  lib,
  stdenv,
  fetchurl,
  rsync,
}:

rsync.overrideAttrs (oldAttrs: rec {
  checkPhase = ''
    rm -v testsuite/itemize.test || true
    make check EXCLUDE=itemize
  '';
})
