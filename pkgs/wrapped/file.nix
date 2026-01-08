{
  lib,
  stdenv,
  fetchurl,
  file,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_file" "--magic-file" "$root/share/misc/magic.mgc" "$@"
  '';
in

file.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/file $out/bin/_file
    cp ${wrapperScript} $out/bin/file
    chmod +x $out/bin/file
  '';
})
