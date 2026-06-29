# markdownlint-cli2 (on static node)
#
# markdownlint-cli2 running on our fully-static (musl) `nodejs-slim24` package,
# instead of being `nix bundle`'d into a self-extracting executable. Same
# runtime approach as packages/pnpm: reuse the upstream nixpkgs JS distribution
# and ship a relative-path wrapper that invokes the sibling static node
# explicitly, so the static node travels with the deployed tool instead of
# depending on a node on the host PATH after the standalone normalize pass.
#
# Unlike pnpm/prettier, the interpreter is NOT overridden at build time: this is
# an npm-based buildNpmPackage tool whose build needs `npm`, which nodejs-slim
# lacks. So it is built with the regular node and only switches to the sibling
# static node at runtime via the wrapper below.
#
# Upstream nixpkgs ships markdownlint-cli2 as:
#   $out/bin/markdownlint-cli2                          (wrapper invoking node)
#   $out/lib/node_modules/markdownlint-cli2/...         (the JS + node_modules)
#
# Deploy layout:
#   $store/
#     nodejs-slim24/bin/node            (separate package; static musl ELF)
#     markdownlint-cli2/
#       bin/markdownlint-cli2           (wrapper -> sibling node + entry .mjs)
#       libexec/markdownlint-cli2/...   (JS, from the nixpkgs markdownlint-cli2)
#
# Verification:
#   $out/bin/markdownlint-cli2 --help   # (with sibling node present)
{
  lib,
  stdenvNoCC,
  writeText,
  markdownlint-cli2,
  nodejs-slim24,
}:

let
  wrapper = writeText "markdownlint-cli2-wrapper.sh" ''
    #!/usr/bin/env bash
    script_path="$(readlink -f "$0")"
    root="$(cd "$(dirname "$script_path")/.." && pwd)"
    store="$(cd "$root/.." && pwd)"
    exec "$store/nodejs-slim24/bin/node" "$root/libexec/markdownlint-cli2/markdownlint-cli2-bin.mjs" "$@"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "markdownlint-cli2";
  inherit (markdownlint-cli2) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    # Reuse the upstream nixpkgs markdownlint-cli2's JS distribution.
    mkdir -p $out/libexec
    cp -R ${markdownlint-cli2}/lib/node_modules/markdownlint-cli2 $out/libexec/markdownlint-cli2

    # Replace the upstream bin wrapper with a relative-path wrapper that invokes
    # the sibling static node explicitly.
    mkdir -p $out/bin
    cp ${wrapper} $out/bin/markdownlint-cli2
    chmod +x $out/bin/markdownlint-cli2

    runHook postInstall
  '';

  # Even though markdownlint-cli2 is *built* with the regular node (it needs
  # npm), make sure the shipped JS actually runs on the static `nodejs-slim24`
  # we deploy alongside it — i.e. the exact command the runtime wrapper issues.
  # markdownlint-cli2 has no --version/--help that exits 0, so lint a trivial
  # clean markdown file and assert success.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    check_dir=$(mktemp -d)
    printf '# Title\n\nHello world.\n' > "$check_dir/ok.md"
    ( cd "$check_dir" && ${nodejs-slim24}/bin/node \
        $out/libexec/markdownlint-cli2/markdownlint-cli2-bin.mjs ok.md )
    runHook postInstallCheck
  '';

  meta = {
    description = "markdownlint-cli2 running on the sibling fully-static (musl) node package";
    homepage = "https://github.com/DavidAnson/markdownlint-cli2";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "markdownlint-cli2";
  };
}
