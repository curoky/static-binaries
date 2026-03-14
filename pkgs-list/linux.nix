{ }:
{
  aria2 = { };
  cronie = { };
  ethtool = { };
  iproute2 = { };
  iptables = { };
  iputils = { };
  libcap = { };
  lsb-release = { };
  man = { };
  numactl = { };
  strace = { };
  indent = { };
  krb5 = { };
  procps = { };
  nettools = { };
  smartmontools = { };
  lua = { };
  exiftool = {
    version = "25.05";
  };
  tmux = { };
  nixfmt = { };
  shellcheck = { };

  # s6-overlay
  s6 = { };
  s6-rc = { };
  s6-linux-init = { };
  s6-linux-utils = { };
  s6-portable-utils = { };
  s6-networking = { };
  s6-dns = { };
  skalibs = { };
  execline = { };

  # go pkgs
  bazelisk = { };
  buildifier = { };
  croc = { };
  dive = {
    version = "25.11";
  };
  fzf = { };
  gdu = { };
  gh = { };
  git-lfs = { };
  go-task = { };
  gost = { };
  lefthook = { };
  oras = { };
  scc = { };
  shfmt = { };

  # llvm pkgs
  lld_18 = { };
  lld_19 = { };
  lld_20 = { };
  lld_21 = { };
  lld_22 = { };

  "llvmPackages_18.clang-unwrapped" = {
    alias = "clang18";
  };
  "llvmPackages_19.clang-unwrapped" = {
    alias = "clang19";
  };
  "llvmPackages_20.clang-unwrapped" = {
    alias = "clang20";
  };
  "llvmPackages_21.clang-unwrapped" = {
    alias = "clang21";
  };
  "llvmPackages_22.clang-unwrapped" = {
    alias = "clang22";
  };
}
