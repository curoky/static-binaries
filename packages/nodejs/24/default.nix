# nodejs-slim24 (static)
#
# A standalone, fully-static (musl) Node.js 24 runtime, exposed as its own
# package (deploy dir name: `nodejs-slim24`) so other packages can reference it
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
  pkgsStaticNode = pkgsStatic.extend (
    _: prev: {
      ada = prev.ada.overrideAttrs { doCheck = false; };
      libuv = prev.libuv.overrideAttrs { doCheck = false; };
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

  # Pin to the major-24 attribute so this package's version doesn't drift with
  # nixpkgs' default `nodejs-slim` alias.
  patchedNode = pkgsStaticNode.nodejs-slim_24.overrideAttrs (old: {
    configureFlags = builtins.filter (
      f:
      # Under pkgsStatic the static stdenv adapter appends the autotools flags
      # `--enable-static --disable-shared`, but node uses a Python
      # `configure.py` that rejects `--disable-shared` ("gyp: --disable-shared
      # not found / Error running GYP"). Strip those autotools flags.
      f != "--enable-static"
      && f != "--disable-shared"
      # Make node use its own bundled copies of brotli and simdutf instead of
      # the system static libraries:
      #   - brotli: the system static build ships split archives
      #     (libbrotli{common,enc,dec}.a) which the single-pass musl GNU ld
      #     fails to link in the right order, leaving common symbols (e.g.
      #     `_kBrotliPrefixCodeRanges`) undefined.
      #   - simdutf: nixpkgs pins simdutf 6.5.0 for node < 25, but node 24's
      #     string_bytes.cc references newer simdutf API
      #     (`simdutf::base64_to_binary_safe`) absent from 6.5.0, causing
      #     undefined references at link time.
      && f != "--shared-brotli"
      && f != "--shared-simdutf"
      && !(lib.hasPrefix "--shared-brotli-libpath=" f)
      && !(lib.hasPrefix "--shared-simdutf-libpath=" f)
    ) old.configureFlags;
    buildInputs = builtins.filter (
      p: !(lib.hasInfix "brotli" (p.name or "")) && !(lib.hasInfix "simdutf" (p.name or ""))
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
# consumers reference $store/nodejs-slim24/bin/node. pname is fixed to
# `nodejs-slim24` (the source dir already encodes the major version).
patchedNode.overrideAttrs (_: {
  pname = "nodejs-slim24";
  # pname change recomputes name; we're not changing the actual version.
  __intentionallyOverridingVersion = true;
})
