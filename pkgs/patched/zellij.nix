{
  lib,
  stdenv,
  fetchurl,
  zellij,
}:

zellij.overrideAttrs (oldAttrs: rec {
  doCheck = false;
  doInstallCheck = false;
})
