{
  lib,
  stdenv,
  fetchFromGitHub,
  oh-my-zsh,
  zsh-syntax-highlighting,
  zsh-autosuggestions,
  zsh-completions,
  zsh-fast-syntax-highlighting,
}:

stdenv.mkDerivation rec {
  version = "1.0.0";
  pname = "zsh-plugs";

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
    cp -r ${oh-my-zsh.out} $out/
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
