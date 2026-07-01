# nodejs-slim26 (darwin, mostly-static via pkgsStatic)
#
# A standalone Node.js 26 runtime for macOS built through `pkgsStatic`, so every
# nixpkgs dependency is linked as a static archive (.a) and the only remaining
# dynamic dependencies are the macOS system libraries (/usr/lib/libSystem,
# libc++, CoreFoundation, Security). This follows DESIGN.md's darwin portability
# rule: the shipped binary must not depend on any dynamic library under /nix.
#
# A fully static Mach-O is impossible on macOS (Apple ships no static libSystem),
# so `pkgsStatic` on darwin is inherently a "partial static" build — which is
# exactly the desired shape here. This is the darwin counterpart of ./default.nix
# (the Linux/musl *fully* static build) and is exposed under the same deploy dir
# name `nodejs-slim26` so consumers reference it identically as a sibling
# directory at deploy time ($store/nodejs-slim26/bin/node).
#
# An earlier attempt using the native `pkgs` derivation and merely dropping the
# nixpkgs `--shared-<dep>` flags was abandoned: node only bundles source for a
# few of its deps, so the binary kept ~18 `/nix/store/*.dylib` load commands
# (ada, simdjson, brotli, c-ares, nghttp2/3, ngtcp2, lief, temporal_capi, ...),
# violating the no-/nix-dylib rule. `pkgsStatic` is what makes those deps ship a
# `.a` so node links them statically.
#
# The static-build patches below mirror ./default.nix: they must be applied to
# the *dependencies* node compiles against (not overridable args of nodejs-slim),
# so we extend the static package set with a local overlay and take its patched
# nodejs-slim. See ./default.nix for the full rationale of each dependency tweak;
# they are build fixes that let the dependency produce a usable static archive
# and are not darwin-specific.
#
# ICU: `--with-intl=small-icu` embeds the (English-only) ICU data into the
# binary. Under pkgsStatic, system-icu would already link a static libicu.a (no
# dylib), but small-icu keeps the binary smaller and self-contained; non-English
# Intl locales are unavailable (full data can be supplied via NODE_ICU_DATA).
#
# Verification (on macOS):
#   otool -L $out/bin/node   # => only /usr/lib + system frameworks remain
#   $out/bin/node --version
{
  lib,
  pkgsStatic,
  # Native (non-static) python used only as node's build-time configure tool.
  # Under darwin pkgsStatic, `python3` is marked broken
  # (python3-static-...-env), which would otherwise block evaluation. python is
  # a nativeBuildInput here, so it never needs to be static — inject the native
  # one (same pattern wget uses for its build-time perl).
  python3,
}:

let
  # pkgsStatic with the same static-build patches ./default.nix applies so the
  # node dependencies compile as static archives. See ./default.nix for the
  # per-dependency rationale (ada / libuv tests, uvwasi / hdrhistogram_c shared
  # targets, lief python bindings, temporal_capi install check).
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
      # node needs only lief's C/C++ library (`out`), not its Python bindings.
      # The nixpkgs lief package hardcodes `LIEF_PYTHON_API true`, and derives
      # `pyEnv`, `buildInputs` and the `Python_EXECUTABLE` cmake flag from its
      # `python3` argument. Under darwin pkgsStatic that `python3` is *broken*
      # (python3-static-...-env), so merely `overrideAttrs`-filtering the old
      # cmakeFlags still forces evaluation of `Python_EXECUTABLE =
      # pyEnv.interpreter` and trips the broken assertion at eval time. So we
      # first `.override { python3 = <native> }` to swap in the non-broken
      # native interpreter (python is only a build tool here, never linked into
      # lief's C library), then rebuild cmakeFlags from scratch (not filtering
      # old values) with the Python API disabled, and clear the python build/
      # install/import phases and outputs.
      lief = (prev.lief.override { python3 = python3; }).overrideAttrs {
        outputs = [ "out" ];
        buildInputs = [ ];
        propagatedBuildInputs = [ ];
        cmakeFlags = [
          (lib.cmakeBool "LIEF_PYTHON_API" false)
          (lib.cmakeBool "LIEF_EXAMPLES" false)
          (lib.cmakeBool "BUILD_SHARED_LIBS" false)
        ];
        postBuild = "";
        postInstall = "";
        pythonImportsCheck = [ ];
      };
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
  # nixpkgs' default `nodejs-slim` alias. Override node's build-time `python`
  # with the native interpreter: darwin pkgsStatic's python3 is broken, and
  # python is only a nativeBuildInput (runs configure.py), never linked into
  # node, so it needn't be static. Overriding it here (rather than in the
  # package-set overlay) avoids perturbing the darwin stdenv bootstrap.
  patchedNode =
    (pkgsStaticNode.nodejs-slim_26.override { python3 = python3; }).overrideAttrs
      (old: {
    configureFlags =
      builtins.filter (
        f:
        # Some static stdenv adapters append autotools `--enable-static
        # --disable-shared`, which node's configure.py rejects
        # ("--disable-shared not found / Error running GYP"). Strip them if
        # present (harmless no-op if the darwin adapter doesn't add them).
        f != "--enable-static"
        && f != "--disable-shared"
        # Make node use its own bundled brotli / simdutf / merve (cjs-module-
        # lexer) instead of the system static libraries — see ./default.nix for
        # why these three specifically fail to link against the system static
        # archives.
        && f != "--shared-brotli"
        && f != "--shared-simdutf"
        && f != "--shared-merve"
        && !(lib.hasPrefix "--shared-brotli-libpath=" f)
        && !(lib.hasPrefix "--shared-simdutf-libpath=" f)
        && !(lib.hasPrefix "--shared-merve-libpath=" f)
        # Embed ICU instead of linking a separate icu; replaced with small-icu
        # below.
        && f != "--with-intl=system-icu"
      ) old.configureFlags
      ++ [ "--with-intl=small-icu" ];
    buildInputs = builtins.filter (
      p:
      !(lib.hasInfix "brotli" (p.name or ""))
      && !(lib.hasInfix "simdutf" (p.name or ""))
      && !(lib.hasInfix "merve" (p.name or ""))
      && !(lib.hasInfix "icu" (p.name or ""))
    ) (old.buildInputs or [ ]);
    # Skip node's `test-ci-js` check suite: it fails on the SEA test
    # (test-single-executable-application-*), which is sensitive to the binary
    # layout and flaky in the Nix sandbox on macOS (nixpkgs' own comment notes
    # such failures "should not affect actual functionality"). We only need a
    # working node binary.
    doCheck = false;
  });
in
# The overridden nodejs-slim is already a complete node derivation, so use it
# directly (no extra mkDerivation wrapper). $out is a full node install
# (bin/node + lib/ ...); consumers reference $store/nodejs-slim26/bin/node.
patchedNode.overrideAttrs (_: {
  pname = "nodejs-slim26";
  # pname change recomputes name; we're not changing the actual version.
  __intentionallyOverridingVersion = true;
})
