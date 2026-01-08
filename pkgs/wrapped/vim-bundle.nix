{
  lib,
  stdenv,
  vimPlugins,
  vim,
  writeText,
}:

let
  inherit (vimPlugins) vim-plug;
  inherit (vimPlugins) vim-airline;
  inherit (vimPlugins) vim-airline-themes;
  inherit (vimPlugins) vim-colors-solarized;
  inherit (vimPlugins) indentLine;
  inherit (vimPlugins) vim-commentary;
  inherit (vimPlugins) vim-fugitive;
  inherit (vimPlugins) vim-gitgutter;
  inherit (vimPlugins) nerdtree;
  inherit (vimPlugins) nerdtree-git-plugin;

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

stdenv.mkDerivation rec {
  pname = "vim-bundle";
  version = "1.0.0";

  nativeBuildInputs = [ ];

  unpackPhase = ":";

  buildPhase = ":";

  installPhase = ''
    cp -r ${vim.out} $out/

    mkdir -p $out/share/
    # cp -r ${vim-plug.src}/ $out/share/
    # chmod +w $out/share/
    mkdir -p $out/share/vim-plugin/autoload
    cp ${vim-plug.src}/plug.vim $out/share/vim-plugin/autoload/
    mkdir -p $out/share/vim-plugin/plugged
    cp -r ${vim-airline}/ $out/share/vim-plugin/plugged/vim-airline
    cp -r ${vim-airline-themes}/ $out/share/vim-plugin/plugged/vim-airline-themes
    cp -r ${vim-colors-solarized}/ $out/share/vim-plugin/plugged/vim-colors-solarized
    cp -r ${indentLine}/ $out/share/vim-plugin/plugged/indentLine
    cp -r ${vim-commentary}/ $out/share/vim-plugin/plugged/vim-commentary
    cp -r ${vim-fugitive}/ $out/share/vim-plugin/plugged/vim-fugitive
    cp -r ${vim-gitgutter}/ $out/share/vim-plugin/plugged/vim-gitgutter
    cp -r ${nerdtree}/ $out/share/vim-plugin/plugged/nerdtree
    cp -r ${nerdtree-git-plugin}/ $out/share/vim-plugin/plugged/nerdtree-git-plugin
  '';

  meta = with lib; {
    description = "vim bundle";
  };
}
