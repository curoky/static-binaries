# pnpm (on static node)
#
# pnpm running on our fully-static (musl) `nodejs-slim24` package.
#
# The interpreter selection is done upstream-style in packages/local.nix:
#   pnpm = pkgs.pnpm.override { nodejs-slim = nodejs-slim24; }
# so the `pnpm` argument here is already the nixpkgs pnpm built against our
# static node (its $out has libexec/pnpm + bin/{pnpm,pnpx}).
#
# This derivation just re-exposes that pnpm with a deploy-friendly entry point:
# upstream's $out/bin/pnpm is a symlink to libexec/pnpm/bin/pnpm.mjs that relies
# on the .mjs shebang to locate node. After the standalone normalize pass that
# shebang's /nix/store path is rewritten to `/usr/bin/env node`, which would
# make the deployed pnpm depend on a node on the host PATH. Instead we ship a
# relative-path wrapper that invokes the sibling `nodejs-slim24` package
# explicitly, so the static node travels with pnpm:
#
#   $store/
#     nodejs-slim24/bin/node   (separate package; static musl ELF)
#     pnpm/
#       bin/{pnpm,pnpx}        (wrapper: exec $store/nodejs-slim24/bin/node \
#                                             $root/libexec/pnpm/bin/<entry> "$@")
#       libexec/pnpm/...       (pnpm JS, from the overridden nixpkgs pnpm)
#
# Verification:
#   $out/bin/pnpm --version   # => pnpm version (with sibling node present)
{
  lib,
  stdenvNoCC,
  writeText,
  pnpm,
}:

let
  # v11 entry points are ESM (.mjs); older majors are .cjs.
  ext = if lib.versionOlder pnpm.version "11" then "cjs" else "mjs";

  # Relative-path wrapper. $root is this package's deploy dir; $store its parent
  # (the dir holding all deployed packages). The static node lives in the
  # sibling `node` package. node is invoked explicitly so the bundled JS
  # shebang is irrelevant. $1 of the template selects the pnpm/pnpx entry.
  mkWrapper =
    entry:
    writeText "${entry}-wrapper.sh" ''
      #!/usr/bin/env bash
      script_path="$(readlink -f "$0")"
      root="$(cd "$(dirname "$script_path")/.." && pwd)"
      store="$(cd "$root/.." && pwd)"
      exec "$store/nodejs-slim24/bin/node" "$root/libexec/pnpm/bin/${entry}.${ext}" "$@"
    '';
in
stdenvNoCC.mkDerivation {
  pname = "pnpm";
  inherit (pnpm) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    # Reuse the overridden nixpkgs pnpm's JS distribution.
    mkdir -p $out/libexec
    cp -R ${pnpm}/libexec/pnpm $out/libexec/pnpm

    # Replace the upstream bin symlinks with relative-path wrappers that invoke
    # the sibling static node explicitly.
    mkdir -p $out/bin
    cp ${mkWrapper "pnpm"} $out/bin/pnpm
    cp ${mkWrapper "pnpx"} $out/bin/pnpx
    chmod +x $out/bin/pnpm $out/bin/pnpx

    runHook postInstall
  '';

  meta = {
    description = "pnpm running on the sibling fully-static (musl) node package";
    homepage = "https://pnpm.io/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pnpm";
  };
}
