{
  lib,
  stdenv,
  fetchurl,
  makeself,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_makeself" "--header" "$root/share/makeself/makeself-header.sh" "$@"
  '';
in

makeself.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/makeself $out/bin/_makeself
    cp ${wrapperScript} $out/bin/makeself
    chmod +x $out/bin/makeself
  '';
})
