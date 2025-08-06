{ lib, stdenv, fetchurl, p7zip}:

p7zip.overrideAttrs (oldAttrs: rec {
  preConfigure = oldAttrs.preConfigure + "
    buildFlags=default
  ";

  outputs = [
    "out"
    "doc"
    "man"
  ];
})
