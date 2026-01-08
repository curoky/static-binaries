{
  lib,
  stdenv,
  fetchurl,
  miniserve,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    if [[ -z $MINISERVE_ENABLE_TAR_GZ ]]; then
      export MINISERVE_ENABLE_TAR_GZ=true
    fi

    if [[ -z $MINISERVE_ENABLE_TAR ]]; then
      export MINISERVE_ENABLE_TAR=true
    fi

    if [[ -z $MINISERVE_ENABLE_ZIP ]]; then
      export MINISERVE_ENABLE_ZIP=true
    fi

    if [[ -z $MINISERVE_DIRS_FIRST ]]; then
      export MINISERVE_DIRS_FIRST=true
    fi

    if [[ -z $MINISERVE_SHOW_SYMLINK_INFO ]]; then
      export MINISERVE_SHOW_SYMLINK_INFO=true
    fi

    if [[ -z $MINISERVE_SHOW_WGET_FOOTER ]]; then
      export MINISERVE_SHOW_WGET_FOOTER=true
    fi

    exec -a "$0" "$root/bin/_miniserve" "$@"
  '';
in

miniserve.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/miniserve $out/bin/_miniserve
    cp ${wrapperScript} $out/bin/miniserve
    chmod +x $out/bin/miniserve
  '';
})
