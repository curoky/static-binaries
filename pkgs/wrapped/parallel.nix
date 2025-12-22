{ lib, stdenv, parallel}:

parallel.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/.parallel-wrapped $out/bin/parallel
  '';
})
