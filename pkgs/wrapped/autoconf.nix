{
  lib,
  stdenv,
  fetchurl,
  autoconf,
  writeText,
}:

let
  autoconf_script = ./autoconf;
in

autoconf.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/autoconf $out/bin/_autoconf
    mv $out/bin/autoheader $out/bin/_autoheader
    mv $out/bin/autom4te $out/bin/_autom4te
    mv $out/bin/autoreconf $out/bin/_autoreconf
    mv $out/bin/autoscan $out/bin/_autoscan
    mv $out/bin/autoupdate $out/bin/_autoupdate
    mv $out/bin/ifnames $out/bin/_ifnames

    cp -r ${autoconf_script}/* $out/bin
    chmod +x $out/bin/autoconf
    chmod +x $out/bin/autoheader
    chmod +x $out/bin/autom4te
    chmod +x $out/bin/autoreconf
    chmod +x $out/bin/autoscan
    chmod +x $out/bin/autoupdate
    chmod +x $out/bin/ifnames
  '';
})
