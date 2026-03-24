{ }:
{
  bash = { };
  binutils-unwrapped = {
    alias = "binutils";
  };
  bison = { };
  bzip2 = {
    output = "bin";
  };
  connect = { };
  findutils = { };
  flac = {
    output = "bin";
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
    output = "bin";
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
    output = "bin";
  };
  pkg-config-unwrapped = {
    alias = "pkg-config";
  };
  snappy = {
    output = "bin";
  };
  sqlite = {
    output = "bin";
  };
  tree = { };
  tzdata = {
    output = "out";
  };
  xxd = { };
  unzip = { };
  util-linux = { };
  xz = {
    output = "bin";
  };
  zip = { };
  zlib = {
    output = "bin";
  };
  zlib-ng = {
    output = "bin";
  };
  zstd = {
    output = "bin";
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
  nerd-fonts.fira-code = {
    isStatic = false;
  };
  nerd-fonts.ubuntu-mono = {
    isStatic = false;
  };

  # rust pkgs
  atuin = { };
  bat = { };
  # biome = { };
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
  uv = { };
  yazi-unwrapped = {
    alias = "yazi";
  };

}
