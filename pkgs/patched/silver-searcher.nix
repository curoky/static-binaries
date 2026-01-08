{
  lib,
  stdenv,
  fetchurl,
  silver-searcher,
}:

silver-searcher.overrideAttrs (oldAttrs: rec {
  NIX_LDFLAGS = "";
})
