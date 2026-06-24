{
  lib,
  s6,
}:

# The s6 binaries (e.g. s6-svscan referencing .../bin/s6-supervise) bake their
# own $bin store path via the shared skaware builder's `--enable-absolute-paths`
# flag. Drop it so the binaries rely on $PATH instead of an absolute store path.
s6.overrideAttrs (oldAttrs: {
  configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;
})
