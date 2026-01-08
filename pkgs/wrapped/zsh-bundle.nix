{
  lib,
  stdenv,
  fetchFromGitHub,
  writeText,
  zsh,
  oh-my-zsh,
  zsh-syntax-highlighting,
  zsh-autosuggestions,
  zsh-completions,
  zsh-fast-syntax-highlighting,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    export FPATH=$FPATH:$root/share/zsh/5.9/functions:$root/share/oh-my-zsh/custom/plugins/zsh-completions/src:$root/share/oh-my-zsh/custom/plugins/conda-zsh-completion

    exec -a "$0" "$root/bin/_zsh" "$@"
  '';

  zsh_static = zsh.overrideAttrs (oldAttrs: rec {
    patchPhase = oldAttrs.patchPhase or "" + ''
      echo "link=either" >> Src/Modules/system.mdd
      echo "link=either" >> Src/Modules/regex.mdd
      echo "link=either" >> Src/Modules/mathfunc.mdd

      substituteInPlace Src/Modules/termcap.c \
        --replace '#ifndef HAVE_BOOLCODES' '#if 0'
    '';

    outputs = [
      "out"
      "man"
    ];

    postInstall = ''
      mv $out/bin/zsh $out/bin/_zsh
      cp ${wrapperScript} $out/bin/zsh
      chmod +x $out/bin/zsh
    '';
  });
in

stdenv.mkDerivation rec {
  version = "1.0.0";
  pname = "zsh-bundle";

  srcs = [
    (fetchFromGitHub {
      owner = "conda-incubator";
      repo = "conda-zsh-completion";
      rev = "v0.11";
      sha256 = "sha256-OKq4yEBBMcS7vaaYMgVPlgHh7KQt6Ap+3kc2hOJ7XHk=";
      name = "conda-zsh-completion";
    })
  ];

  sourceRoot = ".";
  strictDeps = true;
  buildInputs = [
  ];

  installPhase = ''
    cp -r ${zsh_static.out} $out/

    mkdir -p $out/share/
    chmod +w $out/share/
    cp -r ${oh-my-zsh.out}/share/oh-my-zsh $out/share/oh-my-zsh
    chmod +w $out/share/oh-my-zsh/custom/plugins/
    cp -r ${zsh-autosuggestions.src}/ $out/share/oh-my-zsh/custom/plugins/zsh-autosuggestions
    cp -r ${zsh-syntax-highlighting.src}/ $out/share/oh-my-zsh/custom/plugins/zsh-syntax-highlighting
    cp -r ${zsh-completions.src}/ $out/share/oh-my-zsh/custom/plugins/zsh-completions
    cp -r ${zsh-fast-syntax-highlighting.src}/ $out/share/oh-my-zsh/custom/plugins/zsh-fast-syntax-highlighting
    cp -r conda-zsh-completion $out/share/oh-my-zsh/custom/plugins/
  '';

  meta = with lib; {
    description = "zsh bundle";
  };
}
