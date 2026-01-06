{ lib, stdenv, vimPlugins}:

let
  inherit (vimPlugins) vim-plug;
  inherit (vimPlugins) delimitMate;
  inherit (vimPlugins) vim-airline;
  inherit (vimPlugins) vim-airline-themes;
  inherit (vimPlugins) vim-colors-solarized;
  inherit (vimPlugins) indentLine;
  inherit (vimPlugins) vim-commentary;
  inherit (vimPlugins) vim-fugitive;
  inherit (vimPlugins) vim-gitgutter;
  inherit (vimPlugins) nerdtree;
  inherit (vimPlugins) nerdtree-git-plugin;
in

stdenv.mkDerivation rec {
  pname = "vim-plugs";
  version = "1.0.0";

  nativeBuildInputs = [];

  unpackPhase = ":";

  buildPhase = ":";

  installPhase = ''
    mkdir -p $out/share/
    # cp -r ${vim-plug.src}/ $out/share/
    # chmod +w $out/share/
    mkdir -p $out/share/vim-plugin/autoload
    cp ${vim-plug.src}/plug.vim $out/share/vim-plugin/autoload/
    mkdir -p $out/share/vim-plugin/plugged
    cp -r ${delimitMate}/ $out/share/vim-plugin/plugged/delimitMate
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
