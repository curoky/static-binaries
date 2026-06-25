{
  lib,
  s6,
}:

# The s6 binaries (e.g. s6-svscan referencing .../bin/s6-supervise) bake their
# own $bin store path via the shared skaware builder's `--enable-absolute-paths`
# flag. Drop it so the binaries rely on $PATH instead of an absolute store path.
s6.overrideAttrs (oldAttrs: {
  configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;

  # S6_LIBEXECPREFIX is always set to the absolute $libexecdir (the s6
  # configure script hardcodes it regardless of --enable-absolute-paths), so
  # s6-ftrig-listen bakes a /nix/store path to s6-ftrigrd. Blank it out after
  # configure so libs6 looks up s6-ftrigrd via $PATH instead.
  postConfigure = ''
    sed -i 's|^#define S6_LIBEXECPREFIX .*|#define S6_LIBEXECPREFIX ""|' \
      src/include/s6/config.h
  '';
})
