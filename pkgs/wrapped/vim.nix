{
  lib,
  stdenv,
  fetchurl,
  vim,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    # https://askubuntu.com/questions/445686/vim-cannot-find-syntax-vim

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    if [[ -z $VIMRUNTIME ]]; then
      export VIMRUNTIME=$root/share/vim/vim91
    fi

    exec -a "$0" "$root/bin/_vim" "$@"
  '';
in

vim.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/vim $out/bin/_vim
    cp ${wrapperScript} $out/bin/vim
    chmod +x $out/bin/vim
  '';
})
