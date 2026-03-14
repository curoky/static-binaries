{
  lib,
  stdenv,
  fetchurl,
  mold,
  llvmPackages_21,
}:
let
  clang = llvmPackages_21.clang-unwrapped.overrideAttrs (oldAttrs: rec {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ mold ];
    env = {
      NIX_CFLAGS_COMPILE =
        (oldAttrs.NIX_CFLAGS_COMPILE or "") + " -g0 -ffunction-sections -fdata-sections";
      NIX_LDFLAGS = (oldAttrs.NIX_LDFLAGS or "") + " --gc-sections -s";
    };

    cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
      "-DCMAKE_BUILD_TYPE=MinSizeRel"
      "-DLLVM_USE_LINKER=mold"
    ];
  });
in

stdenv.mkDerivation rec {
  pname = "clang-tools";
  version = "21.0.0";

  unpackPhase = ":";
  buildPhase = ":";

  installPhase = ''
    mkdir -p $out/bin
    cp ${clang}/bin/clang-format $out/bin/
  '';
}
