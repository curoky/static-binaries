{
  lib,
  perlPackages,
  pkgsStatic,
  rsync,
  writeText,
}:

let
  # exiftool is a pure-Perl tool: an `exiftool` script plus the Image::ExifTool
  # modules. The only portability problem is its optional compression XS deps
  # (Archive::Zip, Compress::Raw::{Lzma,Bzip2,Zlib}, IO::Compress::Brotli),
  # whose .bundle/.so files dynamically link /nix/store compression dylibs
  # (libz/liblzma/libbz2/libbrotli). normalize.sh does not rewrite Mach-O load
  # commands, so those /nix references would survive and break the portability
  # rule.
  #
  # Fix per the darwin portability ladder (DESIGN.md strategy 2): link every
  # nix dependency statically and leave only system libs dynamic. Each XS
  # module's nixpkgs definition points its build at `pkgs.<lib>` dirs that
  # contain a .dylib; we re-point those at the matching `pkgsStatic.<lib>` lib
  # dirs, which only ship a static .a, so the linker statically embeds the
  # compression libraries and the resulting .bundle depends only on
  # /usr/lib/libSystem.B.dylib.
  #
  # macOS-only: on Linux the sibling static perl (-Uusedl) cannot dlopen any XS
  # .so, so these modules are instead compiled straight into the interpreter —
  # see ./default.nix and packages/perl/default.nix.
  CompressRawZlib = perlPackages.CompressRawZlib.overrideAttrs (_: {
    preConfigure = ''
      cat > config.in <<EOC
        BUILD_ZLIB   = False
        INCLUDE      = ${pkgsStatic.zlib.dev}/include
        LIB          = ${pkgsStatic.zlib.out}/lib
        OLD_ZLIB     = False
        GZIP_OS_CODE = AUTO_DETECT
        USE_ZLIB_NG  = False
      EOC
    '';
  });

  CompressRawBzip2 = perlPackages.CompressRawBzip2.overrideAttrs (old: {
    env = (old.env or { }) // {
      BZIP2_LIB = "${pkgsStatic.bzip2.out}/lib";
      BZIP2_INCLUDE = "${pkgsStatic.bzip2.dev}/include";
    };
  });

  CompressRawLzma = perlPackages.CompressRawLzma.overrideAttrs (_: {
    preConfigure = ''
      cat > config.in <<EOC
        INCLUDE      = ${pkgsStatic.xz.dev}/include
        LIB          = ${pkgsStatic.xz.out}/lib
      EOC
    '';
  });

  IOCompressBrotli = perlPackages.IOCompressBrotli.overrideAttrs (old: {
    postPatch = ''
      substituteInPlace Makefile.PL \
        --replace-fail "@LIBS@" "-L${pkgsStatic.brotli.lib}/lib -lbrotlienc -lbrotlidec -lbrotlicommon"
    '';
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = "-I${lib.getDev pkgsStatic.brotli}/include";
    };
  });

  # IO-Compress (pure Perl) pulls Compress::Raw::{Zlib,Bzip2} and Lzma; rebuild
  # it on top of the static-linked Zlib/Bzip2 so its closure carries the static
  # variants instead of the dynamic ones.
  IOCompress = perlPackages.IOCompress.overrideAttrs (old: {
    propagatedBuildInputs =
      (lib.filter (
        d:
        !(lib.elem (d.pname or "") [
          "Compress-Raw-Zlib"
          "Compress-Raw-Bzip2"
        ])
      ) old.propagatedBuildInputs)
      ++ [
        CompressRawZlib
        CompressRawBzip2
      ];
  });

  exiftool = perlPackages.ImageExifTool.overrideAttrs (_: {
    propagatedBuildInputs = with perlPackages; [
      ArchiveZip
      CompressRawLzma
      IOCompress
      IOCompressBrotli
    ];
  });

  # The shipped script runs against the sibling static `perl` package at deploy
  # time (like cloc) instead of the host perl. PERL5LIB is pointed at the
  # bundled module tree so exiftool finds Image::ExifTool and the (statically
  # linked) compression modules without any /nix paths.
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    store=$root/..

    export PERL5LIB=$root/lib/perl5/site_perl/${perlPackages.perl.version}:$root/lib/perl5:$PERL5LIB
    exec -a "$0" "$store/perl/bin/perl" "$root/bin/_exiftool" "$@"
  '';
in

exiftool.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ rsync ];
  doInstallCheck = false;

  postInstall = ''
    chmod +w $out/bin
    mv $out/bin/exiftool $out/bin/_exiftool
    cp ${wrapperScript} $out/bin/exiftool
    chmod +x $out/bin/exiftool

    mkdir -p $out/lib/perl5
    for dep in \
      ${perlPackages.ArchiveZip} \
      ${CompressRawZlib} \
      ${CompressRawBzip2} \
      ${CompressRawLzma} \
      ${IOCompress} \
      ${IOCompressBrotli} \
      ${perlPackages.FileSlurper} \
      ${perlPackages.GetoptLong}; do
      [ -d "$dep/lib/perl5" ] && rsync -a "$dep/lib/perl5/" $out/lib/perl5/
    done
    # The exiftool script's own Image::ExifTool modules are already under
    # $out/lib/perl5/site_perl from the upstream install.
  '';
})
