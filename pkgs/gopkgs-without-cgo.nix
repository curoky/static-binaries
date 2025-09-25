# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{ pkgs ? import <nixpkgs> { } }:

let
  gdu = pkgs.gdu.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  gh = pkgs.gh.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  bazelisk = pkgs.bazelisk.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  croc = pkgs.croc.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  go_task = pkgs.go-task.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  git_lfs = pkgs.git-lfs.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  gost = pkgs.gost.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  shfmt = pkgs.shfmt.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  fzf = pkgs.fzf.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  dive = pkgs.dive.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  scc = pkgs.scc.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  buildifier = pkgs.buildifier.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
  lefthook = pkgs.lefthook.overrideAttrs (oldAttrs: rec {
    env.CGO_ENABLED = "0";
  });
in
{
  inherit shfmt;
  inherit fzf;
  inherit bazelisk;
  inherit croc;
  inherit gdu;
  inherit gh;
  inherit git_lfs;
  inherit go_task;
  inherit gost;
  inherit dive;
  inherit scc;
  inherit buildifier;
  inherit lefthook;
}
