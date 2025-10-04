{ lib, stdenv, fetchurl, python313, writeText, termcap}:

let
  Modules_Setup_local = ./Setup.313;
in
python313.overrideAttrs (oldAttrs: rec {
    # https://wiki.python.org/moin/BuildStatically
    # https://github.com/python/cpython/blob/3.11/Modules/Setup
    configureFlags = oldAttrs.configureFlags ++ [
      "LDFLAGS=-L${termcap}/lib"
      #"--with-ensurepip=install"
    ];
    stripIdlelib = true;
    stripTests = true;
    stripTkinter = true;
    postPatch = oldAttrs.postPatch + ''
      cp ${Modules_Setup_local} Modules/Setup.local
    '';
})
