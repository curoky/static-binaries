{
  lib,
  stdenv,
  fetchurl,
  diffutils,
}:

diffutils.overrideAttrs (oldAttrs: rec {
  doCheck = false;
})
