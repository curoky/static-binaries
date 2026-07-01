# nodejs-slim26 (static)
#
# A standalone, fully-static (musl) Node.js 26 runtime, exposed as its own
# package (deploy dir name: `nodejs-slim26`) so other packages can reference it
# as a sibling directory at deploy time (the same convention dool/netron use for
# the `python311` package: $store/<pkg-name>/bin/<interpreter>).
#
# This package owns the static-build patches. The ada / libuv / uvwasi tweaks
# must be applied to the *dependencies* node is compiled against, which are not
# exposed as overridable args of nodejs-slim (they are args of the inner
# nodejs.nix, pulled in via callPackage). So `.override` can't reach them and we
# extend the static package set with an overlay, then take its patched
# nodejs-slim. node's own derivation (configureFlags / buildInputs / doCheck) is
# then adjusted with `.overrideAttrs`. Keeping the overlay local to this package
# avoids mutating shared static packages used by other consumers (e.g. ngtcp2).
#
# The Node SEA single-file approach was abandoned: flipping the SEA fuse on
# nixpkgs' node 24 segfaults in V8 init before any JS runs, on both dynamic and
# static builds — unrelated to the static deps patched here.
#
# Verification:
#   file $out/bin/node   # => "ELF ... statically linked"
#   $out/bin/node --version
{
  lib,
  pkgsStatic,
}:

let
  # pkgsStatic with the static-build patches needed to compile a fully static
  # (musl) nodejs-slim:
  #   - ada / libuv: tests disabled. Under pkgsStatic their test suites fail
  #     inside the Nix build sandbox (ada's `basic_fuzzer` exe isn't built in
  #     the static toolchain; libuv's `udp_try_send` fails with -98/EADDRINUSE
  #     due to the sandbox's restricted network).
  #   - uvwasi: its CMakeLists hardcodes `add_library(uvwasi SHARED ...)`,
  #     ignoring BUILD_SHARED_LIBS, so the static toolchain fails to link the
  #     unwanted libuvwasi.so (R_X86_64_32 against crtbeginT.o). Force that
  #     target to STATIC (renamed output to avoid clashing with the existing
  #     uvwasi_a static lib); node only needs the static lib anyway.
  #   - hdrhistogram_c (new dependency in node 26): its CMakeLists builds a
  #     SHARED `hdr_histogram` target by default; under the static toolchain
  #     linking that .so fails (R_X86_64_32 against crtbeginT.o, same as
  #     uvwasi). Disable the shared target via the upstream CMake option, which
  #     leaves only the static archive — but CMake names it
  #     `libhdr_histogram_static.a`, whereas node's gyp link line uses plain
  #     `-lhdr_histogram` (the shared lib's name). With the shared lib gone the
  #     link fails ("cannot find -lhdr_histogram"), so add a `libhdr_histogram.a`
  #     symlink pointing at the static archive. Also disable the bundled
  #     tests/examples (HDR_HISTOGRAM_BUILD_PROGRAMS): the examples
  #     (`hdr_decoder`, `hiccup`) fail to compile (`#include <hdr/hdr_histogram.h>`
  #     not on the include path) and node doesn't need them; disabling them
  #     also removes the check phase, so doCheck is turned off to match.
  pkgsStaticNode = pkgsStatic.extend (
    _: prev: {
      ada = prev.ada.overrideAttrs { doCheck = false; };
      libuv = prev.libuv.overrideAttrs { doCheck = false; };
      hdrhistogram_c = prev.hdrhistogram_c.overrideAttrs (old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          "-DHDR_HISTOGRAM_BUILD_SHARED=OFF"
          "-DHDR_HISTOGRAM_BUILD_PROGRAMS=OFF"
        ];
        postInstall = (old.postInstall or "") + ''
          ln -s $out/lib/libhdr_histogram_static.a $out/lib/libhdr_histogram.a
        '';
        doCheck = false;
      });
      # lief (linked by node since 25.6 via `useSharedLief`): the nixpkgs lief
      # package hardcodes `LIEF_PYTHON_API true` and builds Python bindings,
      # pulling in python3 + pydantic -> pydantic-core (a Rust/maturin cdylib).
      # Under pkgsStatic that chain is built for the musl static target, where
      # maturin cannot produce a cdylib ("target ... does not support these
      # crate types"), so the build fails on pydantic-core. node only needs
      # lief's C/C++ library (`out`), not the Python bindings (`py`), so build
      # lief with the Python API disabled to cut the whole Python dependency.
      #
      # The python deps (pydantic, build, pip, scikit-build-core, ...) reach
      # lief's runtime closure via `propagatedBuildInputs`, not `buildInputs`:
      # under pkgsStatic the python builders move host python libraries from
      # buildInputs into propagatedBuildInputs, so clearing buildInputs alone
      # leaves pydantic-core in the closure. We must also clear
      # propagatedBuildInputs (alongside dropping the `py` output and disabling
      # LIEF_PYTHON_API / the python build+install/import-check phases).
      lief = prev.lief.overrideAttrs (old: {
        outputs = [ "out" ];
        buildInputs = [ ];
        propagatedBuildInputs = [ ];
        cmakeFlags =
          builtins.filter (f: !(lib.hasInfix "LIEF_PYTHON_API" f) && !(lib.hasInfix "Python_EXECUTABLE" f)) (
            old.cmakeFlags or [ ]
          )
          ++ [ (lib.cmakeBool "LIEF_PYTHON_API" false) ];
        postBuild = "";
        postInstall = "";
        pythonImportsCheck = [ ];
      });
      # temporal_capi (new dependency in node 26, the Rust impl of the Temporal
      # API): its installCheckPhase compiles and *runs* C/C++ programs against
      # the freshly built lib. Under the static musl cross toolchain that check
      # breaks — the `pkg-config` it calls is the target-prefixed cross wrapper
      # (`x86_64-...-pkg-config`), so the bare `pkg-config` invocation fails with
      # "command not found", and the test binaries are static target binaries
      # not meant to run in the build sandbox. node only needs the resulting
      # library / headers / .pc file, so skip the install check.
      temporal_capi = prev.temporal_capi.overrideAttrs { doInstallCheck = false; };
      uvwasi = prev.uvwasi.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace CMakeLists.txt \
            --replace-fail \
              'add_library(uvwasi SHARED ''${uvwasi_sources})' \
              'add_library(uvwasi STATIC ''${uvwasi_sources})
          set_target_properties(uvwasi PROPERTIES OUTPUT_NAME "uvwasi_noshared")'
        '';
      });
    }
  );

  # Pin to the major-26 attribute so this package's version doesn't drift with
  # nixpkgs' default `nodejs-slim` alias.
  patchedNode = pkgsStaticNode.nodejs-slim_26.overrideAttrs (old: {
    configureFlags = builtins.filter (
      f:
      # Under pkgsStatic the static stdenv adapter appends the autotools flags
      # `--enable-static --disable-shared`, but node uses a Python
      # `configure.py` that rejects `--disable-shared` ("gyp: --disable-shared
      # not found / Error running GYP"). Strip those autotools flags.
      f != "--enable-static"
      && f != "--disable-shared"
      # Make node use its own bundled copies of brotli, simdutf and merve
      # (the cjs-module-lexer C++ lib) instead of the system static libraries:
      #   - brotli: the system static build ships split archives
      #     (libbrotli{common,enc,dec}.a) which the single-pass musl GNU ld
      #     fails to link in the right order, leaving common symbols (e.g.
      #     `_kBrotliPrefixCodeRanges`) undefined.
      #   - simdutf: node bundles a simdutf version matched to its sources; the
      #     system static simdutf can lag behind, causing undefined references
      #     at link time when node references newer simdutf API.
      #   - merve (new dependency in node 26): the system `merve` (cjs-module-
      #     lexer) is compiled against the system simdutf, so libmerve.a
      #     references `simdutf::detail::find`, a symbol absent from node's
      #     bundled simdutf — linking node_mksnapshot then fails with an
      #     undefined reference. Bundling merve makes it use node's own simdutf.
      && f != "--shared-brotli"
      && f != "--shared-simdutf"
      && f != "--shared-merve"
      && !(lib.hasPrefix "--shared-brotli-libpath=" f)
      && !(lib.hasPrefix "--shared-simdutf-libpath=" f)
      && !(lib.hasPrefix "--shared-merve-libpath=" f)
    ) old.configureFlags;
    buildInputs = builtins.filter (
      p:
      !(lib.hasInfix "brotli" (p.name or ""))
      && !(lib.hasInfix "simdutf" (p.name or ""))
      && !(lib.hasInfix "merve" (p.name or ""))
    ) (old.buildInputs or [ ]);
    # The check phase builds native test addons (test/js-native-api/*,
    # build-{js-native,node}-api-tests) which link `.node` shared objects.
    # Under the fully static (musl) gcc toolchain that fails with `relocation
    # R_X86_64_32 against hidden symbol __TMC_END__ can not be used when making
    # a shared object` (static CRT crtbeginT.o is not PIC). These test addons
    # are irrelevant to the node binary, so skip the checks.
    doCheck = false;
  });
in
# The overridden nodejs-slim is already a complete node derivation, so use it
# directly as this package's result (no need to wrap it in another mkDerivation
# just to copy the binary). $out is a full node install (bin/node + lib/ etc.);
# consumers reference $store/nodejs-slim26/bin/node. pname is fixed to
# `nodejs-slim26` (the source dir already encodes the major version).
patchedNode.overrideAttrs (_: {
  pname = "nodejs-slim26";
  # pname change recomputes name; we're not changing the actual version.
  __intentionallyOverridingVersion = true;
})
