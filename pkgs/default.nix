# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{ pkgs ? import <nixpkgs> { },
  old ? import <old> { },
  staging ? import <staging> { },
  unstable ? import <unstable> { },
}:

let
in
{
  protobuf_3_8_0 = pkgs.pkgsStatic.callPackage ./protobuf-generic-v3.nix ({
    version = "3.8.0";
    sha256 = "sha256-qK4Tb6o0SAN5oKLHocEIIKoGCdVFQMeBONOQaZQAlG4=";
  });

  protobuf_3_9_2 = pkgs.pkgsStatic.callPackage ./protobuf-generic-v3.nix ({
    version = "3.9.2";
    sha256 = "sha256-1mLSNLyRspTqoaTFylGCc2JaEQOMR1WAL7ffwJPqHyA=";
  });

  rsync = pkgs.pkgsStatic.rsync.override {
    enableXXHash = false;
  };
  coreutils = pkgs.pkgsStatic.coreutils.override {
    singleBinary = false;
  };
  glibcLocales = pkgs.glibcLocales.override {
    allLocales = false;
  };

  # patched
  diffutils = pkgs.pkgsStatic.callPackage ./patched/diffutils.nix { };
  cmake = pkgs.pkgsStatic.callPackage ./patched/cmake.nix {};
  zellij = pkgs.pkgsStatic.callPackage ./patched/zellij.nix { };
  git = pkgs.pkgsStatic.callPackage ./patched/git.nix { };
  gettext = pkgs.pkgsStatic.callPackage ./patched/gettext.nix { };
  p7zip = pkgs.pkgsStatic.callPackage ./patched/p7zip.nix { };
  cloc = pkgs.pkgsStatic.callPackage ./patched/cloc.nix { };
  
  # python3
  python311 = pkgs.pkgsStatic.callPackage ./python3/python311.nix { };
  python312 = pkgs.pkgsStatic.callPackage ./python3/python312.nix { };
  python313 = pkgs.pkgsStatic.callPackage ./python3/python313.nix { };

  # pypkgs
  dool = pkgs.pkgsStatic.callPackage ./pypkgs/dool.nix { };
  netron = pkgs.pkgsStatic.callPackage ./pypkgs/netron.nix { };
  git-filter-repo = pkgs.pkgsStatic.callPackage ./pypkgs/git-filter-repo.nix { };

  # wrapped
  # bat = pkgs.pkgsStatic.callPackage ./wrapped/bat.nix { };
  vim = pkgs.pkgsStatic.callPackage ./wrapped/vim.nix { };
  # vim-bundle = pkgs.pkgsStatic.callPackage ./wrapped/vim-bundle.nix { };
  curl = pkgs.pkgsStatic.callPackage ./wrapped/curl.nix { };
  file = pkgs.pkgsStatic.callPackage ./wrapped/file.nix { };
  makeself = pkgs.pkgsStatic.callPackage ./wrapped/makeself.nix { };
  miniserve = pkgs.pkgsStatic.callPackage ./wrapped/miniserve.nix { };
  openssh_gssapi = pkgs.pkgsStatic.callPackage ./wrapped/openssh_gssapi.nix { };
  # tmux-bundle = pkgs.pkgsStatic.callPackage ./wrapped/tmux-bundle.nix { };
  wget = pkgs.pkgsStatic.callPackage ./wrapped/wget.nix { };
  zsh = pkgs.pkgsStatic.callPackage ./wrapped/zsh.nix { };
  zsh-bundle = pkgs.pkgsStatic.callPackage ./wrapped/zsh-bundle.nix { };
  autoconf = pkgs.pkgsStatic.callPackage ./wrapped/autoconf.nix { };
  automake = pkgs.pkgsStatic.callPackage ./wrapped/automake.nix { };
  libtool = pkgs.pkgsStatic.callPackage ./wrapped/libtool.nix { };

  cacert = pkgs.pkgsStatic.callPackage ./cacert.nix { };
  nsight-systems = pkgs.pkgsStatic.callPackage ./nsight-systems.nix { };
  rime-extra = pkgs.pkgsStatic.callPackage ./rime-extra.nix { };
  tmux-extra = pkgs.pkgsStatic.callPackage ./tmux-extra.nix { };
  vim-extra = pkgs.callPackage ./vim-extra.nix { };
  zsh-extra = pkgs.pkgsStatic.callPackage ./zsh-extra.nix { };
}
