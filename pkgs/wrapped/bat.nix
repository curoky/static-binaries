{
  lib,
  stdenv,
  fetchurl,
  bat,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    if [[ -z $BAT_THEME ]]; then
      export BAT_THEME="Solarized (light)"
    fi

    exec -a "$0" "$root/bin/_bat" "$@"
  '';
in

bat.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/bat $out/bin/_bat
    cp ${wrapperScript} $out/bin/bat
    chmod +x $out/bin/bat
  '';
})
