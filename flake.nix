{
  description = "Manual Precision Factory with Multi-Version Support";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-staging.url = "github:NixOS/nixpkgs/staging";
    nixpkgs-2511.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  nixConfig = {
    extra-substituters = [
      "https://curoky-static-binaries-v2.cachix.org"
    ];
    extra-trusted-public-keys = [
      "curoky-static-binaries-v2.cachix.org-1:fz4EbiwDeisCH9c1a7ItzRlF6BMEkugFBDeagmMIbsQ="
    ];
  };

  outputs =
    { self, ... }@inputs:
    let
      lib = inputs.nixpkgs-unstable.lib;
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        system:
        let
          mkEnv = input: {
            pkgs = import input { inherit system; };
            pkgsStatic = (import input { inherit system; }).pkgsStatic;
          };

          envs = {
            "unstable" = mkEnv inputs.nixpkgs-unstable;
            "25.11" = mkEnv inputs.nixpkgs-2511;
            "25.05" = mkEnv inputs.nixpkgs-2505;
            "24.11" = mkEnv inputs.nixpkgs-2411;
            "24.05" = mkEnv inputs.nixpkgs-2405;
          };

          defaultPkgs = envs.unstable.pkgs;
          defaultPkgsStatic = envs.unstable.pkgsStatic;
          Pkgs2511 = envs."25.11".pkgs;
          Pkgs2511Static = envs."25.11".pkgsStatic;
          Pkgs2505 = envs."25.05".pkgs;
          Pkgs2505Static = envs."25.05".pkgsStatic;

          isDarwin = lib.hasSuffix "darwin" system;

          manifest =
            let
              common = import ./pkgs-list/common.nix { };
              specific =
                if (isDarwin) then import ./pkgs-list/macos.nix { } else import ./pkgs-list/linux.nix { };
            in
            common // specific;

          upstreamPkgs = lib.concatMapAttrs (
            name: conf:
            let
              targetVer = conf.version or "unstable";
              env = envs.${targetVer};
              base = if (conf.isStatic or true) then env.pkgsStatic else env.pkgs;

              # rawPkg = base.${name} or (throw "Package ${name} not found in nixpkgs-${targetVer}");
              # rawPkg = lib.attrByPath (lib.splitString "." name) null base;
              rawPkg = base.${name} or (lib.attrByPath (lib.splitString "." name) null base);

              selectedOutput = conf.output or "out";
              finalDrv = lib.getOutput selectedOutput rawPkg;

              finalName = conf.alias or name;
            in
            {
              "${finalName}" = finalDrv;
            }
          ) manifest;

          customPkgs = {
            protobuf_3_8_0 = defaultPkgsStatic.callPackage ./pkgs/protobuf-generic-v3.nix ({
              version = "3.8.0";
              sha256 = "sha256-qK4Tb6o0SAN5oKLHocEIIKoGCdVFQMeBONOQaZQAlG4=";
            });
            protobuf_3_9_2 = defaultPkgsStatic.callPackage ./pkgs/protobuf-generic-v3.nix ({
              version = "3.9.2";
              sha256 = "sha256-1mLSNLyRspTqoaTFylGCc2JaEQOMR1WAL7ffwJPqHyA=";
            });
            coreutils = defaultPkgsStatic.coreutils.override {
              singleBinary = false;
            };
            gnupg = defaultPkgsStatic.gnupg.override {
              enableMinimal = true;
              guiSupport = false;
            };

            # patched
            diffutils = defaultPkgsStatic.callPackage ./pkgs/patched/diffutils.nix { };
            gettext = defaultPkgsStatic.callPackage ./pkgs/patched/gettext.nix { };
            p7zip = defaultPkgsStatic.callPackage ./pkgs/patched/p7zip.nix { };
            rsync = defaultPkgsStatic.callPackage ./pkgs/patched/rsync.nix { };

            # pypkgs
            dool = defaultPkgsStatic.callPackage ./pkgs/pypkgs/dool.nix { };
            netron = defaultPkgsStatic.callPackage ./pkgs/pypkgs/netron.nix { };
            git-filter-repo = defaultPkgsStatic.callPackage ./pkgs/pypkgs/git-filter-repo.nix { };

            # wrapped
            vim = defaultPkgsStatic.callPackage ./pkgs/wrapped/vim.nix { };
            curl = defaultPkgsStatic.callPackage ./pkgs/wrapped/curl.nix { };
            file = defaultPkgsStatic.callPackage ./pkgs/wrapped/file.nix { };
            makeself = defaultPkgsStatic.callPackage ./pkgs/wrapped/makeself.nix { };
            zsh = Pkgs2511Static.callPackage ./pkgs/wrapped/zsh.nix { };
            autoconf = defaultPkgsStatic.callPackage ./pkgs/wrapped/autoconf.nix { };
            automake = defaultPkgsStatic.callPackage ./pkgs/wrapped/automake.nix { };
            libtool = defaultPkgsStatic.callPackage ./pkgs/wrapped/libtool.nix { };

            cacert = defaultPkgsStatic.callPackage ./pkgs/cacert.nix { };
            rime-plugs = defaultPkgsStatic.callPackage ./pkgs/rime-plugs.nix { };
            tmux-plugs = defaultPkgsStatic.callPackage ./pkgs/tmux-plugs.nix { };
            vim-plugs = defaultPkgs.callPackage ./pkgs/vim-plugs.nix { };
            zsh-plugs = defaultPkgsStatic.callPackage ./pkgs/zsh-plugs.nix { };
            music-decrypto = defaultPkgs.callPackage ./pkgs/music-decrypto.nix { };
          };

          linux_only = {
            glibcLocales = defaultPkgs.glibcLocales.override {
              allLocales = false;
            };
            nsight-systems = defaultPkgsStatic.callPackage ./pkgs/nsight-systems.nix { };
            cmake = defaultPkgsStatic.callPackage ./pkgs/patched/cmake.nix { };
            git = defaultPkgsStatic.callPackage ./pkgs/patched/git.nix { };
            zellij = defaultPkgsStatic.callPackage ./pkgs/patched/zellij.nix { };

            clang-tools-18 = defaultPkgsStatic.callPackage ./pkgs/patched/clang18.nix { };
            clang-tools-19 = defaultPkgsStatic.callPackage ./pkgs/patched/clang19.nix { };
            clang-tools-20 = defaultPkgsStatic.callPackage ./pkgs/patched/clang20.nix { };
            clang-tools-21 = defaultPkgsStatic.callPackage ./pkgs/patched/clang21.nix { };
            clang-tools-22 = defaultPkgsStatic.callPackage ./pkgs/patched/clang22.nix { };

            # python3
            python311 = defaultPkgsStatic.callPackage ./pkgs/python3/python311.nix { };
            python312 = defaultPkgsStatic.callPackage ./pkgs/python3/python312.nix { };
            python313 = defaultPkgsStatic.callPackage ./pkgs/python3/python313.nix { };

            # wrapped
            openssh_gssapi = defaultPkgsStatic.callPackage ./pkgs/wrapped/openssh_gssapi.nix { };
            perl = defaultPkgsStatic.callPackage ./pkgs/wrapped/perl.nix { };
            wget = defaultPkgsStatic.callPackage ./pkgs/wrapped/wget.nix { };
            cloc = defaultPkgsStatic.callPackage ./pkgs/wrapped/cloc.nix { };
            parallel = defaultPkgsStatic.callPackage ./pkgs/wrapped/parallel.nix { };
            miniserve = Pkgs2511Static.callPackage ./pkgs/wrapped/miniserve.nix { };
          };

          go_without_cgo = {
            gdu = Pkgs2511.gdu.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            gh = Pkgs2511.gh.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            bazelisk = Pkgs2511.bazelisk.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            croc = Pkgs2511.croc.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            go-task = Pkgs2511.go-task.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            git-lfs = Pkgs2511.git-lfs.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            #gost = Pkgs2511.gost.overrideAttrs (oldAttrs: rec {
            #  env.CGO_ENABLED = "0";
            #});
            shfmt = Pkgs2511.shfmt.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            fzf = Pkgs2511.fzf.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            dive = Pkgs2511.dive.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            scc = Pkgs2511.scc.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            buildifier = Pkgs2511.buildifier.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            lefthook = Pkgs2511.lefthook.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
            oras = Pkgs2511.oras.overrideAttrs (oldAttrs: rec {
              env.CGO_ENABLED = "0";
            });
          };

          # goOverrides = import ./overrides/go.nix {
          #   pkgs = defaultPkgs;
          #   pkgsStatic = defaultPkgsStatic;
          # };

          # allPackages = upstreamPkgs // goOverrides // customPkgs;
          allPackages =
            upstreamPkgs
            // lib.optionalAttrs (isDarwin) go_without_cgo
            // lib.optionalAttrs (!isDarwin) linux_only
            // customPkgs;

          stripDrv =
            name: drv:
            defaultPkgs.runCommand "${name}-stripped"
              {
                nativeBuildInputs = [
                  defaultPkgs.buildPackages.binutils
                  defaultPkgs.buildPackages.file
                  defaultPkgs.buildPackages.nukeReferences
                ];
                builderScript = ./scripts/patch.sh;
              }
              ''
                mkdir -p $out
                cp -pRH ${drv}/* $out/ 2>/dev/null || true
                chmod -R u+w $out

                bash $builderScript $out
              '';

          strippedPackages = lib.mapAttrs (
            name: drv: if lib.isDerivation drv then stripDrv name drv else drv
          ) allPackages;

        in
        strippedPackages
        // {
          all = defaultPkgs.linkFarm "all-static-toolbox" (
            lib.mapAttrsToList (name: path: { inherit name path; }) (
              lib.filterAttrs (n: v: lib.isDerivation v) strippedPackages # allPackages
            )
          );
        };
    in
    {
      packages = lib.genAttrs systems perSystem;
    };
}
