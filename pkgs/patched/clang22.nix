{
  lib,
  stdenv,
  fetchurl,
  mold,
  llvmPackages_22,
}:

llvmPackages_22.clang-unwrapped.overrideAttrs (oldAttrs: rec {
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
})
