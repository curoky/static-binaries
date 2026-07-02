# psql — the PostgreSQL interactive client, built as a fully-static musl binary.
#
# Only the `psql` client is shipped (the user only needs psql). The stock
# `pkgsStatic.postgresql` build fails here for two reasons, both fixed below:
#
#   1. postgresql's generic.nix switches the compiler from gcc to clang (to
#      enable `-flto`). In this repo's musl64-cross static set clang is broken:
#      it can't find `-lgcc_eh`, is missing `libunwind.a`, and has no usable
#      `lld` (`configure: error: C compiler cannot create executables`). gcc in
#      the same set works fine. generic.nix only keeps the incoming stdenv when
#      `cc.isClang` is already true, so we fake `isClang = true` to keep gcc.
#
#   2. gcc's `-flto` breaks postgres's partial-link (`ld -r`) step, so we drop
#      `-flto` from CFLAGS (keeping the section-GC flags).
#
# A fully-static gcc toolchain also cannot link shared objects, so we skip the
# server backend (charset-conversion `.so` modules) entirely and build only
# libpq's static archive plus psql. libpq's `all`/`all-lib` targets are patched
# to not require the `.so`.
{
  lib,
  stdenv,
  postgresql,
}:
let
  # Keep gcc but make generic.nix believe it already got a clang stdenv, so it
  # does not swap in the (broken) clang toolchain.
  gccAsClang = stdenv // {
    cc = stdenv.cc // {
      isClang = true;
    };
  };
in
(postgresql.override { stdenv = gccAsClang; }).overrideAttrs (old: {
  # Only ship a single self-contained output (the psql client). The stock
  # multi-output split (out/lib/dev/...) creates a reference cycle here since we
  # don't build the server/pg_config that normally separates them.
  outputs = [ "out" ];
  # The stock outputChecks reference the now-removed dev/doc/man/lib outputs.
  outputChecks = { };

  env = (old.env or { }) // {
    # Drop -flto: gcc LTO is incompatible with postgres's partial-link step.
    CFLAGS = "-fdata-sections -ffunction-sections";
  };

  # The inherited postPatch does `--subst-var dev`; with a single output point
  # the dev/doc/man shell vars at $out. Then patch libpq so its `all`/`all-lib`
  # targets build only the static archive (no `.so`, which the static toolchain
  # cannot link).
  postPatch = ''
    export dev="$out" doc="$out" man="$out"
  ''
  + (old.postPatch or "")
  + ''
    substituteInPlace src/Makefile.shlib \
      --replace-fail "all-lib: all-shared-lib" "all-lib: all-static-lib" \
      --replace-fail "install-lib: install-lib-shared" "install-lib: install-lib-static"
    substituteInPlace src/interfaces/libpq/Makefile \
      --replace-fail "all: all-lib libpq-refs-stamp" "all: all-lib"
  '';

  # Single-output build: point every split dir at $out.
  preConfigure = (old.preConfigure or "") + ''
    configureFlagsArray+=(
      "--includedir=$out/include"
      "--mandir=$out/share/man"
      "--docdir=$out/share/doc/postgresql"
      "--libdir=$out/lib"
      "--libexecdir=$out/lib/libexec"
      "--localedir=$out/lib/share/locale"
    )
  '';

  # Build only libpq (static) and psql, skipping the server backend.
  buildPhase = ''
    runHook preBuild
    make -C src/interfaces/libpq all-lib -j$NIX_BUILD_CORES
    make -C src/bin/psql -j$NIX_BUILD_CORES
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    make -C src/interfaces/libpq install
    make -C src/bin/psql install
    runHook postInstall
  '';
  postInstall = "";
})
