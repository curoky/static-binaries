{
  lib,
  perl,
  perlPackages,
  xz,
  brotli,
  writeText,
}:

let
  # Linux: the fully-static musl-cross perl (the `perl` injected by the flake's
  # pkgsStatic callPackage), like every other Linux tool here. The static build
  # has no dylib so no install-name rewriting is needed (see ./darwin.nix for
  # the macOS counterpart).
  #
  # The static perl is built with -Uusedl, i.e. it CANNOT dlopen any XS .so at
  # runtime; every extension must be a static_ext compiled into the interpreter.
  # Upstream pkgsStatic.perl already vendors Compress::Raw::{Zlib,Bzip2} and the
  # IO::Compress::* family, but the two XS compression modules exiftool also
  # wants — Compress::Raw::Lzma and IO::Compress::Brotli — are not in the perl
  # source tree. We inject their CPAN sources under cpan/ so perl's own build
  # harness compiles them as static extensions (linking the static liblzma /
  # libbrotli archives straight into the perl binary). This keeps exiftool's
  # optional lzma/brotli support working without any loadable .so.
  perlWithComp = perl.overrideAttrs (old: {
    preConfigure = (old.preConfigure or "") + ''
      mkdir -p cpan/Compress-Raw-Lzma cpan/IO-Compress-Brotli
      tar --strip-components=1 -C cpan/Compress-Raw-Lzma -xf ${perlPackages.CompressRawLzma.src}
      tar --strip-components=1 -C cpan/IO-Compress-Brotli -xf ${perlPackages.IOCompressBrotli.src}
      find cpan/Compress-Raw-Lzma cpan/IO-Compress-Brotli -type f -exec chmod a-x {} +

      # Point Compress::Raw::Lzma at the static liblzma (xz) archive.
      cat > cpan/Compress-Raw-Lzma/config.in <<EOC
      INCLUDE = ${xz.dev}/include
      LIB     = ${xz.out}/lib
      EOC

      # IO::Compress::Brotli's upstream Makefile.PL builds a vendored copy of
      # brotli via Alien::cmake3, which won't work inside perl's static build
      # harness. Replace it with a minimal one that links the static system
      # brotli archives (order matters: enc/dec depend on common).
      cat > cpan/IO-Compress-Brotli/Makefile.PL <<'EOM'
      use ExtUtils::MakeMaker;
      WriteMakefile(
        NAME         => 'IO::Compress::Brotli',
        VERSION_FROM => 'lib/IO/Compress/Brotli.pm',
        ABSTRACT     => 'Read/write Brotli buffers/streams',
        LICENSE      => 'perl',
        LIBS         => "@BROTLI_LIBS@",
        INC          => "@BROTLI_INC@",
        META_ADD     => { dynamic_config => 0 },
      );
      EOM
      substituteInPlace cpan/IO-Compress-Brotli/Makefile.PL \
        --replace-fail '@BROTLI_LIBS@' "-L${brotli.lib}/lib -lbrotlienc -lbrotlidec -lbrotlicommon" \
        --replace-fail '@BROTLI_INC@' "-I${lib.getDev brotli}/include"

      # Register the injected files in the top-level MANIFEST so Configure /
      # make_ext discover the extensions. Append only — do NOT reorder MANIFEST,
      # perl's pod/buildtoc step depends on its existing order.
      ( cd cpan/Compress-Raw-Lzma && find . -type f | sed 's#^\./#cpan/Compress-Raw-Lzma/#' ) >> MANIFEST
      ( cd cpan/IO-Compress-Brotli && find . -type f | sed 's#^\./#cpan/IO-Compress-Brotli/#' ) >> MANIFEST
    '';

    postInstall = (old.postInstall or "") + ''
      for m in Compress::Raw::Lzma IO::Compress::Brotli; do
        "$out/bin/perl" -e "require $m; 1" \
          || { echo "ERROR: $m not built into static perl"; exit 1; }
      done
    '';
  });

  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    export PERL5LIB=$root/lib/perl5:$PERL5LIB
    for d in "$root"/lib/perl5/site_perl/*/; do
      [ -d "$d" ] && PERL5LIB=$d:$PERL5LIB
    done
    exec -a "$0" "$root/bin/_perl" "$@"
  '';
in

perlWithComp.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/perl $out/bin/_perl
    cp ${wrapperScript} $out/bin/perl
    chmod +x $out/bin/perl
  '';
})
