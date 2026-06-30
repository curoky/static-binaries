# manifests/default.nix
#
# Single declarative manifest of upstream nixpkgs packages.
#
# Schema (first-level key = package attr name in nixpkgs):
#
#   <pkg> = {
#     # Optional list of systems this package is built for.
#     # Omitted => all systems (see `allSystems` in make-manifest-packages.nix).
#     platforms = [ "x86_64-linux" "aarch64-darwin" ];
#
#     # Package-level shared config, inherited by every platform:
#     version  = "unstable";   # which pinned nixpkgs env (default "unstable")
#     isStatic = true;         # pkgsStatic (true, default) or pkgs (false)
#     output   = [ "out" ];    # derivation outputs to expose (default [ "out" ])
#     alias    = "name";       # rename exported attribute
#
#     # Per-platform overrides. The effective config for a system is
#     # (package-level shared config) // (platform key config), platform wins.
#     "aarch64-darwin" = { version = "24.11"; };
#   };
{
  ## ---- common (all platforms) -------------------------------------------
  bash = { };
  binutils-unwrapped = {
    alias = "binutils";
  };
  bison = { };
  bzip2 = {
    output = [ "bin" ];
  };
  connect = { };
  findutils = { };
  flac = {
    output = [ "bin" ];
  };
  flex = { };
  gawk = { };
  getopt = { };
  gettext = { };
  git-extras = { };
  gnugrep = { };
  gnumake = { };
  gnupatch = { };
  gnused = { };
  gnutar = { };
  gzip = { };
  inetutils = { };
  jq = {
    output = [ "bin" ];
  };
  gdb = {
    version = "25.11";
  };
  less = { };
  lsof = { };
  m4 = { };
  ncdu_1 = { };
  netcat = { };
  ninja = { };
  openssl = {
    output = [ "bin" ];
  };
  pkg-config-unwrapped = {
    alias = "pkg-config";
  };
  snappy = {
    output = [ "bin" ];
  };
  sqlite = {
    output = [ "bin" ];
  };
  tree = { };
  tzdata = {
    output = [ "out" ];
  };
  xxd = { };
  unzip = { };
  util-linux = { };
  xz = {
    output = [ "bin" ];
  };
  zip = { };
  zlib = {
    output = [ "bin" ];
  };
  zlib-ng = {
    output = [ "bin" ];
  };
  zstd = {
    output = [ "bin" ];
  };

  protobuf_25 = { };
  protobuf_27 = { };
  protobuf_29 = { };
  protobuf3_20 = {
    version = "24.05";
  };
  protobuf3_21 = {
    version = "24.05";
  };
  protobuf_23 = {
    version = "24.05";
  };
  protobuf_24 = {
    version = "25.05";
  };
  protobuf_26 = {
    version = "25.05";
  };
  protobuf_28 = {
    version = "25.05";
  };
  patchelf = {
    version = "25.05";
  };

  # font
  fira-code = {
    isStatic = false;
  };
  lxgw-wenkai = {
    isStatic = false;
  };
  "nerd-fonts.fira-code" = {
    isStatic = false;
    alias = "nerd-fonts-fira-code";
  };
  "nerd-fonts.ubuntu-mono" = {
    isStatic = false;
    alias = "nerd-fonts-ubuntu-mono";
  };

  # rust pkgs
  atuin = { };
  bat = { };
  biome = { };
  dprint = { };
  eza = { };
  fd = { };
  git-absorb = { };
  mcfly = { };
  nixpkgs-fmt = { };
  procs = { };
  ripgrep = { };
  ruff = { };
  starship = { };
  tokei = { };
  yazi-unwrapped = {
    alias = "yazi";
  };
  smartmontools = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };

  ## ---- linux only -------------------------------------------------------
  cronie = {
    platforms = [ "x86_64-linux" ];
  };
  ethtool = {
    platforms = [ "x86_64-linux" ];
  };
  iproute2 = {
    platforms = [ "x86_64-linux" ];
  };
  iptables = {
    platforms = [ "x86_64-linux" ];
  };
  iputils = {
    platforms = [ "x86_64-linux" ];
  };
  libcap = {
    platforms = [ "x86_64-linux" ];
  };
  lsb-release = {
    platforms = [ "x86_64-linux" ];
  };
  man = {
    platforms = [ "x86_64-linux" ];
  };
  numactl = {
    platforms = [ "x86_64-linux" ];
  };
  strace = {
    platforms = [ "x86_64-linux" ];
  };
  indent = {
    platforms = [ "x86_64-linux" ];
  };
  krb5 = {
    platforms = [ "x86_64-linux" ];
  };
  procps = {
    platforms = [ "x86_64-linux" ];
  };
  nettools = {
    platforms = [ "x86_64-linux" ];
  };
  lua = {
    platforms = [ "x86_64-linux" ];
  };
  exiftool = {
    platforms = [ "x86_64-linux" ];
    "x86_64-linux" = {
      version = "25.05";
    };
  };
  tmux = {
    platforms = [ "x86_64-linux" ];
  };
  nixfmt = {
    platforms = [ "x86_64-linux" ];
  };
  nil = {
    platforms = [ "x86_64-linux" ];
  };

  s6-linux-utils = {
    platforms = [ "x86_64-linux" ];
    output = [ "bin" ];
  };
  s6-portable-utils = {
    platforms = [ "x86_64-linux" ];
    output = [ "bin" ];
  };
  s6-networking = {
    platforms = [ "x86_64-linux" ];
    output = [ "bin" ];
  };
  s6-dns = {
    platforms = [ "x86_64-linux" ];
    output = [ "bin" ];
  };
  skalibs = {
    platforms = [ "x86_64-linux" ];
  };

  # go pkgs (linux only)
  bazelisk = {
    platforms = [ "x86_64-linux" ];
  };
  buildifier = {
    platforms = [ "x86_64-linux" ];
  };
  croc = {
    platforms = [ "x86_64-linux" ];
  };
  delve = {
    platforms = [ "x86_64-linux" ];
  };
  dive = {
    platforms = [ "x86_64-linux" ];
    "x86_64-linux" = {
      version = "25.11";
    };
  };
  fzf = {
    platforms = [ "x86_64-linux" ];
  };
  gdu = {
    platforms = [ "x86_64-linux" ];
  };
  gh = {
    platforms = [ "x86_64-linux" ];
  };
  git-lfs = {
    platforms = [ "x86_64-linux" ];
    "x86_64-linux" = {
      version = "25.11";
    };
  };
  go-task = {
    platforms = [ "x86_64-linux" ];
  };
  go-tools = {
    platforms = [ "x86_64-linux" ];
  };
  gofumpt = {
    platforms = [ "x86_64-linux" ];
  };
  golangci-lint = {
    platforms = [ "x86_64-linux" ];
  };
  gomodifytags = {
    platforms = [ "x86_64-linux" ];
  };
  gopls = {
    platforms = [ "x86_64-linux" ];
  };
  gotests = {
    platforms = [ "x86_64-linux" ];
  };
  gotools = {
    platforms = [ "x86_64-linux" ];
  };
  gost = {
    platforms = [ "x86_64-linux" ];
  };
  impl = {
    platforms = [ "x86_64-linux" ];
  };
  lefthook = {
    platforms = [ "x86_64-linux" ];
  };
  oras = {
    platforms = [ "x86_64-linux" ];
  };
  scc = {
    platforms = [ "x86_64-linux" ];
  };
  shfmt = {
    platforms = [ "x86_64-linux" ];
  };
  runc = {
    platforms = [ "x86_64-linux" ];
  };

  # llvm pkgs (linux only)
  lld_18 = {
    platforms = [ "x86_64-linux" ];
  };
  lld_19 = {
    platforms = [ "x86_64-linux" ];
  };
  lld_20 = {
    platforms = [ "x86_64-linux" ];
  };
  lld_21 = {
    platforms = [ "x86_64-linux" ];
  };
  lld_22 = {
    platforms = [ "x86_64-linux" ];
  };
  "llvmPackages_18.clang-unwrapped" = {
    platforms = [ "x86_64-linux" ];
    alias = "clang18";
  };
  "llvmPackages_19.clang-unwrapped" = {
    platforms = [ "x86_64-linux" ];
    alias = "clang19";
  };
  "llvmPackages_20.clang-unwrapped" = {
    platforms = [ "x86_64-linux" ];
    alias = "clang20";
  };
  "llvmPackages_21.clang-unwrapped" = {
    platforms = [ "x86_64-linux" ];
    alias = "clang21";
  };
  "llvmPackages_22.clang-unwrapped" = {
    platforms = [ "x86_64-linux" ];
    alias = "clang22";
  };

  ## ---- cross-platform with per-platform overrides -----------------------
  # linux uses default version; darwin pins a specific version.
  aria2 = {
    "aarch64-darwin" = {
      version = "24.11";
    };
  };
  shellcheck = {
    "aarch64-darwin" = {
      version = "25.11";
    };
  };
  uv = {
    "aarch64-darwin" = {
      version = "25.11";
    };
  };

  ## ---- darwin only ------------------------------------------------------
  silver-searcher = {
    platforms = [ "aarch64-darwin" ];
    "aarch64-darwin" = {
      version = "26.05";
    };
  };
}
