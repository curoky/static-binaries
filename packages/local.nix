# local.nix
#
# Locally-defined packages: pinned versions, patched builds, wrapped bundles,
# and platform-specific (Linux-only) tooling. These are the packages where the
# repo does manual work (patch + bundle) rather than just selecting an upstream
# nixpkgs derivation via the manifest.
#
# Returns an attrset:
#   { common = { ... }; linux = { ... }; darwin = { ... }; }
# The caller merges the relevant platform set into the final package set.
{
  lib,
  pkgs,
  pkgsStatic,
  pkgs2605Static,
  pkgs2511,
}:
let
  # Darwin: build a subset of Go tools with CGO disabled to reduce dynamic
  # library dependence (standalone-friendly without a fully static toolchain).
  goWithoutCgo =
    lib.genAttrs
      [
        "gdu"
        "gh"
        "bazelisk"
        "croc"
        "go-task"
        "git-lfs"
        "shfmt"
        "fzf"
        "dive"
        "scc"
        "buildifier"
        "lefthook"
        "oras"
      ]
      (
        name:
        pkgs2511.${name}.overrideAttrs (oldAttrs: {
          env.CGO_ENABLED = "0";
        })
      );
in
{
  # Cross-platform local packages.
  common = {
    protobuf_3_8_0 = pkgsStatic.callPackage ./protobuf/3_8_0 { };
    protobuf_3_9_2 = pkgsStatic.callPackage ./protobuf/3_9_2 { };
    coreutils = pkgsStatic.coreutils.override {
      singleBinary = false;
    };
    gnupg = pkgsStatic.gnupg.override {
      enableMinimal = true;
      guiSupport = false;
    };

    diffutils = pkgsStatic.callPackage ./diffutils { };
    gettext = pkgsStatic.callPackage ./gettext { };
    p7zip = pkgsStatic.callPackage ./p7zip { };
    rsync = pkgsStatic.callPackage ./rsync { };

    netron = pkgs.callPackage ./netron { };
    git-filter-repo = pkgs.callPackage ./git-filter-repo { };

    vim = pkgsStatic.callPackage ./vim { };
    curl = pkgsStatic.callPackage ./curl { };
    file = pkgsStatic.callPackage ./file { };
    makeself = pkgsStatic.callPackage ./makeself { };
    zsh = pkgsStatic.callPackage ./zsh { };
    autoconf = pkgsStatic.callPackage ./autoconf { };
    automake = pkgsStatic.callPackage ./automake { };
    libtool = pkgsStatic.callPackage ./libtool { };

    cacert = pkgsStatic.callPackage ./cacert { };
    rime-plugins = pkgsStatic.callPackage ./rime-plugins { };
    tmux-plugins = pkgsStatic.callPackage ./tmux-plugins { };
    vim-plugins = pkgs.callPackage ./vim-plugins { };
    zsh-plugins = pkgsStatic.callPackage ./zsh-plugins { };
    music-decrypto = pkgs.callPackage ./music-decrypto { };

    # cloc is a perl script; its wrapper runs against the sibling `perl` package
    # at deploy time (falling back to a system perl), so it ships cross-platform.
    # The `perl` package itself is defined per-platform in the linux/darwin sets
    # below (./perl/default.nix on Linux, ./perl/darwin.nix on macOS). cloc needs
    # no static linking (and the fully-static perl/perlPackages it would pull in
    # fail to build on darwin), so build it from the native pkgs on both
    # platforms.
    cloc = pkgs.callPackage ./cloc { };
    # exiftool is a perl tool like cloc: it runs against the sibling `perl`
    # package at deploy time. Its only non-portable bits are the optional
    # compression XS modules, which are rebuilt against `pkgsStatic` so the
    # compression libs link statically (only /usr/lib system libs stay dynamic
    # on darwin). Built from native pkgs.perlPackages on both platforms.
    exiftool = pkgs.callPackage ./exiftool {
      inherit pkgsStatic;
    };
    parallel = pkgs.callPackage ./parallel { };
  };

  # Linux-only local packages (patched tooling, container stack, multiple
  # clang-tools versions, static Python variants, extra wrapped tools).
  linux = rec {
    glibcLocales = pkgs.glibcLocales.override {
      allLocales = false;
    };
    perl = pkgsStatic.callPackage ./perl { };
    nsight-systems = pkgsStatic.callPackage ./nsight-systems { };
    cmake = pkgsStatic.callPackage ./cmake/default { };
    cmake_3_27_9 = pkgsStatic.callPackage ./cmake/3_27_9 { };
    cmake_4_1_2 = pkgsStatic.callPackage ./cmake/4_1_2 { };
    git = pkgsStatic.callPackage ./git { };
    zellij = pkgs2605Static.callPackage ./zellij { };
    execline = pkgsStatic.callPackage ./execline { };
    s6 = pkgsStatic.callPackage ./s6 {
      inherit execline;
    };
    s6-rc = pkgsStatic.callPackage ./s6-rc {
      inherit s6 execline;
    };
    s6-linux-init = pkgsStatic.callPackage ./s6-linux-init {
      inherit s6;
    };

    # podman stack
    gpgme = pkgsStatic.callPackage ./gpgme { };
    crun = pkgsStatic.callPackage ./crun { };
    conmon = pkgsStatic.callPackage ./conmon { };
    catatonit = pkgsStatic.callPackage ./catatonit { };
    podman = pkgsStatic.callPackage ./podman {
      inherit
        catatonit
        crun
        conmon
        gpgme
        ;
    };

    clang-tools-18 = pkgsStatic.callPackage ./clang-tools/18 { };
    clang-tools-19 = pkgsStatic.callPackage ./clang-tools/19 { };
    clang-tools-20 = pkgsStatic.callPackage ./clang-tools/20 { };
    clang-tools-21 = pkgsStatic.callPackage ./clang-tools/21 { };
    clang-tools-22 = pkgsStatic.callPackage ./clang-tools/22 { };

    python311 = pkgsStatic.callPackage ./python/311 { };
    python312 = pkgsStatic.callPackage ./python/312 { };
    python313 = pkgsStatic.callPackage ./python/313 { };
    python314 = pkgsStatic.callPackage ./python/314 { };
    python315 = pkgsStatic.callPackage ./python/315 { };

    dool = pkgs.callPackage ./dool { };

    openssh_gssapi = pkgsStatic.callPackage ./openssh_gssapi { };
    wget = pkgsStatic.callPackage ./wget { };
    miniserve = pkgsStatic.callPackage ./miniserve { };

    # Node.js stack: standalone fully-static (musl) Node.js runtimes plus a set
    # of Node CLI tools that run on them. Each runtime is shipped as its own
    # package (deploy dirs `nodejs-slim24` / `nodejs-slim26`) so the tools can
    # reference it as a sibling directory at deploy time — the same convention
    # dool/netron use for `python311`. Each ./<tool> wrapper reuses the tool's JS
    # distribution and ships a relative-path wrapper that invokes the sibling
    # `nodejs-slim26` package ($store/nodejs-slim26/bin/node) explicitly, so the
    # static node travels with the deployed tool instead of depending on a node
    # on the host PATH after the standalone normalize pass. This supersedes the
    # previous `bundle = true` manifest entries.
    #
    # pnpm/prettier additionally build against our static node by overriding the
    # upstream interpreter (pnpm only unpacks JS; prettier uses pnpm to fetch
    # deps), which exercises the static runtime end-to-end. markdownlint-cli2 and
    # opencommit are npm-based buildNpmPackage tools whose build needs `npm`
    # (absent from nodejs-slim), so they are *built* with the regular node and
    # only switch to the sibling static node at runtime via the wrapper. Their
    # wrapper derivations add an installCheck that runs the shipped JS under
    # `nodejs-slim26` to confirm the tool actually works on the static runtime.
    #
    # nodejs-slim24 is retained as a standalone runtime package; the CLI tools
    # above now target nodejs-slim26.
    nodejs-slim24 = pkgsStatic.callPackage ./nodejs/24 { };
    # node 26 links temporal_capi (a Rust dep). Under a native-static set this
    # rebuilds the whole musl LLVM + rustc toolchain from source. On Linux the
    # `pkgsStatic` passed in here is the musl64 *cross* set (see flake.nix /
    # mkEnv), which instead reuses the cached glibc rustc/LLVM via rust's
    # `fastCross` path. The node output is still a fully-static musl binary.
    nodejs-slim26 = pkgsStatic.callPackage ./nodejs/26 { };
    pnpm = pkgsStatic.callPackage ./pnpm {
      pnpm = pkgs.pnpm.override { nodejs-slim = nodejs-slim26; };
    };
    prettier = pkgsStatic.callPackage ./prettier {
      prettier = pkgs.prettier.override { nodejs = nodejs-slim26; };
    };
    markdownlint-cli2 = pkgsStatic.callPackage ./markdownlint-cli2 {
      inherit nodejs-slim26;
      inherit (pkgs) markdownlint-cli2;
    };
    opencommit = pkgsStatic.callPackage ./opencommit {
      inherit nodejs-slim26;
      inherit (pkgs) opencommit;
    };
  };

  # Darwin-only local packages.
  darwin = goWithoutCgo // {
    perl = pkgs.callPackage ./perl/darwin.nix {
      libxcryptStatic = pkgsStatic.libxcrypt;
    };
    # macOS counterpart of the Linux nodejs-slim26 (./nodejs/26): a standalone
    # Node.js 26 built via pkgsStatic so every nix dependency links as a static
    # archive, leaving only macOS system libs dynamic (full static is
    # impossible on macOS). Exposed under the same deploy dir name so consumers
    # reference it identically.
    nodejs-slim26 = pkgsStatic.callPackage ./nodejs/26/darwin.nix {
      inherit (pkgs) python3 cctools;
    };

    # macOS wget: take the fully-static `pkgsStatic.wget` (same set as Linux) and
    # only override its build-time perl to the native one — the darwin static
    # perl fails to build (see ./wget/darwin-static.nix). The resulting binary
    # links every nix dep statically, leaving only /usr/lib system libs dynamic.
    wget = pkgsStatic.callPackage ./wget/darwin-static.nix {
      inherit (pkgs) perlPackages;
    };
    # Alternative (kept, not active): build native pkgs.wget and swap each
    # non-system dep for its pkgsStatic archive (see ./wget/darwin.nix).
    # wget = pkgs.callPackage ./wget/darwin.nix {
    #   inherit pkgsStatic;
    # };

    # macOS ffmpeg (headless): partial-static via pkgsStatic — every nix dep
    # linked statically, only /usr/lib + system frameworks stay dynamic (DESIGN.md
    # darwin strategy 2). See ./ffmpeg/darwin.nix for the disabled features and
    # their root causes (meson arm64 cross-file bug, openmp/llvm-static libatomic,
    # liboapv dylib-only, network/TLS static configure link failures) and the
    # x265 static-link fixes (kept: 8-bit HEVC encode).
    ffmpeg = pkgsStatic.callPackage ./ffmpeg/darwin.nix { };

    # macOS krb5: fully static via pkgsStatic, with two upstream darwin
    # static-link defects patched (USE_CCAPI_MACOS / mit_des_zeroblock — see
    # ./krb5/darwin.nix). On Linux krb5 comes straight from the manifest.
    krb5 = pkgsStatic.callPackage ./krb5/darwin.nix { };
  };
}
