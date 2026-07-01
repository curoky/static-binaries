{
  perlPackages,
  rsync,
  writeText,
}:

let
  # exiftool is a pure-Perl tool: an `exiftool` script plus the Image::ExifTool
  # modules. Its optional compression support (Compress::Raw::{Zlib,Bzip2,Lzma},
  # IO::Compress::*, Archive::Zip) is the only thing that could pull in native
  # code.
  #
  # Linux strategy: the sibling static `perl` (-Uusedl) cannot dlopen any XS
  # .so, so we do NOT ship separate compiled compression modules here. Instead
  # every XS compression module is compiled straight into that static perl
  # interpreter (see packages/perl/linux.nix, which vendors Compress::Raw::Lzma
  # and IO::Compress::Brotli on top of the Zlib/Bzip2/IO::Compress that upstream
  # pkgsStatic.perl already builds in). So this package only needs to ship the
  # pure-Perl pieces: the exiftool script, the Image::ExifTool modules, and
  # Archive::Zip (pure Perl, which uses the perl-builtin Compress::Raw::Zlib).
  exiftool = perlPackages.ImageExifTool.overrideAttrs (_: {
    propagatedBuildInputs = with perlPackages; [
      ArchiveZip
    ];
  });

  # The shipped script runs against the sibling static `perl` package at deploy
  # time (like cloc) instead of the host perl. PERL5LIB is pointed at the
  # bundled module tree so exiftool finds Image::ExifTool and Archive::Zip
  # without any /nix paths.
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
      ${perlPackages.FileSlurper} \
      ${perlPackages.GetoptLong}; do
      [ -d "$dep/lib/perl5" ] && rsync -a "$dep/lib/perl5/" $out/lib/perl5/
    done
    # The exiftool script's own Image::ExifTool modules are already under
    # $out/lib/perl5/site_perl from the upstream install.
  '';
})
