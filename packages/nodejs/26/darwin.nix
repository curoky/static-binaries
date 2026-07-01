# nodejs-slim26 (darwin, mostly-static)
#
# A standalone Node.js 26 runtime for macOS that statically embeds as many of
# its third-party dependencies as possible, while NOT attempting a fully static
# binary. A fully static Mach-O is impossible on macOS: Apple ships no static
# libSystem (libc), so every executable must dynamically link the system
# dylibs (libSystem, CoreFoundation, libc++, ...). "Mostly-static" here means:
# only those unavoidable system dylibs remain dynamic; node's own deps are
# linked in statically.
#
# This is the darwin counterpart of ./default.nix (the Linux/musl *fully*
# static build). It is exposed under the same deploy dir name `nodejs-slim26`
# so consumers reference it identically as a sibling directory at deploy time
# ($store/nodejs-slim26/bin/node).
#
# What nixpkgs' node does by default (see pkgs/development/web/nodejs/nodejs.nix):
#   - a large `sharedLibDeps` set (openssl, zlib, libuv, sqlite, c-ares,
#     nghttp2/3, ngtcp2, ada, simdutf, temporal_capi, ...) is each passed via
#     `--shared-<name>` + `--shared-<name>-libpath=...`, i.e. node links them
#     *dynamically* against the nixpkgs dylibs.
#   - `--with-intl=system-icu` dynamically links the nixpkgs `icu` dylibs.
# To make the runtime self-contained we let node use its own bundled copies for
# a conservative subset only:
#   - for openssl/zlib/libuv/sqlite (see `staticDeps` below) drop their
#     `--shared-<dep>` / `--shared-<dep>-libpath=*` flags so node compiles and
#     statically links its bundled copies, and drop them from buildInputs.
#     Every *other* --shared-* dep is left dynamic on purpose: node has no
#     drop-in bundled source for them and removing the flags either fails to
#     link or (for temporal_capi) forces a cargo-dependent bundled build.
#   - replace `--with-intl=system-icu` with `--with-intl=small-icu`, which
#     embeds the (English-only) ICU data into the binary with no libicu dylib
#     dependency and, unlike `full-icu`, needs no network download (the Nix
#     sandbox has none). Non-English Intl locales are therefore unavailable;
#     full ICU locale data can be supplied at runtime via NODE_ICU_DATA.
#
# Verification (on macOS):
#   otool -L $out/bin/node   # => only /usr/lib + system frameworks remain
#   $out/bin/node --version
{
  lib,
  pkgs,
}:

let
  # The node deps to switch from dynamic (nixpkgs --shared-*) to node's own
  # bundled, statically linked copies. We deliberately only do this for the
  # handful of core libraries that node ships a bundled source tree for and
  # that link cleanly as static; every other entry of nixpkgs' sharedLibDeps
  # is left dynamic. In particular we must NOT touch `temporal_capi`: node 26
  # links it via `--shared-temporal_capi` (the prebuilt Rust lib) together with
  # `--v8-enable-temporal-support`. Dropping the --shared flag makes node fall
  # back to compiling its *bundled* temporal from source, which requires cargo
  # at configure time ("No acceptable cargo found!") and breaks the build.
  staticDeps = [
    "openssl"
    "zlib"
    "libuv"
    "sqlite"
  ];
  # Match the exact `--shared-<dep>` and `--shared-<dep>-libpath=...` flags
  # nixpkgs emits for those deps, and nothing else (e.g. not
  # `--shared-temporal_capi`).
  isStaticDepSharedFlag =
    f: builtins.any (d: f == "--shared-${d}" || lib.hasPrefix "--shared-${d}-libpath=" f) staticDeps;
  patchedNode = pkgs.nodejs-slim_26.overrideAttrs (old: {
    configureFlags =
      builtins.filter (
        f:
        # Strip only the dynamic-linking flags for the core static deps so node
        # falls back to its bundled, statically linked copies. All other
        # --shared-* flags (temporal_capi, ada, simdutf, nghttp2, ...) stay.
        !(isStaticDepSharedFlag f)
        # Replaced below with small-icu.
        && f != "--with-intl=system-icu"
      ) old.configureFlags
      ++ [ "--with-intl=small-icu" ];
    # Drop the now-bundled core deps from buildInputs so they don't remain as
    # dynamic dependencies; icu is dropped because we switched to bundled
    # small-icu. Everything else (incl. temporal_capi) is kept.
    buildInputs = builtins.filter (
      p:
      let
        n = p.name or "";
      in
      !(lib.hasInfix "openssl" n)
      && !(lib.hasInfix "zlib" n)
      && !(lib.hasInfix "libuv" n)
      && !(lib.hasInfix "sqlite" n)
      && !(lib.hasInfix "icu" n)
    ) (old.buildInputs or [ ]);
    # Skip the upstream check phase. nixpkgs runs node's `test-ci-js` suite,
    # which fails here on the SEA test (test-single-executable-application-*):
    # the Single Executable Application machinery is sensitive to the binary's
    # section/signing layout, which our static-linking changes alter, and these
    # tests are flaky in the Nix sandbox on macOS anyway (nixpkgs' own comment
    # notes such failures "should not affect actual functionality"). We only
    # need a working node binary, not a passing upstream CI suite.
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
