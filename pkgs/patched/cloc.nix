{ lib, cloc, perl}:

cloc.overrideAttrs (oldAttrs: rec {
  nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ perl ];
})
