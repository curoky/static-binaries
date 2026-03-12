{
  lib,
  stdenv,
  fetchurl,
  cloc,
}:

cloc.overrideAttrs (oldAttrs: rec {
  doInstallCheck = false;
})
