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
#   - sharedLibDeps = { openssl, zlib, libuv, sqlite } are passed via
#     `--shared-<name>` + `--shared-<name>-libpath=...`, i.e. node links them
#     *dynamically* against the nixpkgs dylibs.
#   - `--with-intl=system-icu` dynamically links the nixpkgs `icu` dylibs.
# To make the runtime self-contained we instead let node use its own bundled
# copies:
#   - drop every `--shared-*` / `--shared-*-libpath=*` flag so node compiles
#     and statically links its bundled openssl/zlib/libuv/sqlite;
#   - replace `--with-intl=system-icu` with `--with-intl=small-icu`, which
#     embeds the (English-only) ICU data into the binary with no libicu dylib
#     dependency and, unlike `full-icu`, needs no network download (the Nix
#     sandbox has none). Non-English Intl locales are therefore unavailable;
#     full ICU locale data can be supplied at runtime via NODE_ICU_DATA.
#   - drop those libraries (and icu) from buildInputs so they don't end up as
#     dynamic dependencies.
#
# Verification (on macOS):
#   otool -L $out/bin/node   # => only /usr/lib + system frameworks remain
#   $out/bin/node --version
{
  lib,
  pkgs,
}:

let
  patchedNode = pkgs.nodejs-slim_26.overrideAttrs (old: {
    configureFlags =
      builtins.filter (
        f:
        # Strip the dynamic-linking flags for openssl/zlib/libuv/sqlite so node
        # falls back to its bundled, statically linked copies.
        !(lib.hasPrefix "--shared-" f)
        # Replaced below with small-icu.
        && f != "--with-intl=system-icu"
      ) old.configureFlags
      ++ [ "--with-intl=small-icu" ];
    # These were linked dynamically via the --shared-* flags removed above;
    # drop them so they're not pulled in as runtime dynamic dependencies. icu
    # is dropped because we switched to bundled small-icu.
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
