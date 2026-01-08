{
  lib,
  stdenv,
  fetchurl,
  cmakeMinimal,
}:

cmakeMinimal.overrideAttrs (oldAttrs: rec {
  doCheck = false;
  # cmakeFlags = ["-122"];
  #configureFlags = ["-255"];
  #configureFlags = ["CXXFLAGS=-Wno-elaborated-enum-base --docdir=share/doc/cmake-minimal-3.31.7 --no-system-libs -- -DCMAKE_CXX_COMPILER:STRING=x86_64-unknown-linux-musl-c++ -DCMAKE_C_COMPILER:STRING=x86_64-unknown-linux-musl-cc -DCMAKE_AR:STRING=/nix/store/s417mccczz3vscmsb5g9h7x040gvinfy-x86_64-unknown-linux-musl-binutils-2.44/bin/x86_64-unknown-linux-musl-ar -DCMAKE_RANLIB:STRING=/nix/store/s417mccczz3vscmsb5g9h7x040gvinfy-x86_64-unknown-linux-musl-binutils-2.44/bin/x86_64-unknown-linux-musl-ranlib -DCMAKE_STRIP:STRING=/nix/store/s417mccczz3vscmsb5g9h7x040gvinfy-x86_64-unknown-linux-musl-binutils-2.44/bin/x86_64-unknown-linux-musl-strip -DCMAKE_USE_OPENSSL:BOOL=FALSE -DBUILD_CursesDialog:BOOL=FALSE --enable-static"];
  configureFlags = [
    "CXXFLAGS=-Wno-elaborated-enum-base"
    "--docdir=share/doc/${oldAttrs.pname}-${oldAttrs.version}"
  ]
  ++ [
    "--no-system-libs"
  ] # FIXME: cleanup
  ++ [
    "--"
    # We should set the proper `CMAKE_SYSTEM_NAME`.
    # http://www.cmake.org/Wiki/CMake_Cross_Compiling
    #
    # Unfortunately cmake seems to expect absolute paths for ar, ranlib, and
    # strip. Otherwise they are taken to be relative to the source root of the
    # package being built.
    (lib.cmakeFeature "CMAKE_CXX_COMPILER" "${stdenv.cc.targetPrefix}c++")
    (lib.cmakeFeature "CMAKE_C_COMPILER" "${stdenv.cc.targetPrefix}cc")
    (lib.cmakeFeature "CMAKE_AR" "${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ar")
    (lib.cmakeFeature "CMAKE_RANLIB" "${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ranlib")
    (lib.cmakeFeature "CMAKE_STRIP" "${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}strip")

    (lib.cmakeBool "CMAKE_USE_OPENSSL" false)
    (lib.cmakeBool "BUILD_CursesDialog" false)
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeFeature "CMAKE_EXE_LINKER_FLAGS" "-static")
  ]
  ++ [
    #"--enable-static"
  ];

})
