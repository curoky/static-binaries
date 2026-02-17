{
  lib,
  stdenv,
  fetchurl,
  mold,
  llvmPackages_18,
}:

llvmPackages_18.clang-unwrapped.overrideAttrs (oldAttrs: rec {
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
