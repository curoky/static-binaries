{
  lib,
  stdenv,
  fetchurl,
  automake,
  writeText,
}:

let
  automake_script = ./automake;
in

automake.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/automake $out/bin/_automake
    mv $out/bin/aclocal $out/bin/_aclocal

    cp -r ${automake_script}/* $out/bin
    chmod +x $out/bin/automake
    chmod +x $out/bin/aclocal
  '';
})
