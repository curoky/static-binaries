{
  lib,
  stdenv,
  fetchurl,
  gettext,
}:

gettext.overrideAttrs (oldAttrs: rec {
  configureFlags = oldAttrs.configureFlags ++ [
    "--with-included-gettext"
    "--with-included-libintl"
  ];
})
