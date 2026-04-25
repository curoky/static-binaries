{
  lib,
  stdenv,
  fetchFromGitHub,
  # pkg-config,
  # installShellFiles,
  # buildGoModule,
  # buildPackages,
  gpgme,
  # gnupg,
  lvm2,
  btrfs-progs,
  libapparmor,
  libseccomp,
  libselinux,
  # systemd,
  # nixosTests,
  # python3,
  # makeBinaryWrapper,
  # symlinkJoin,
  replaceVars,
  # extraPackages ? [ ],
  crun,
  # runc,
  conmon,
  # extraRuntimes ? lib.optionals stdenv.hostPlatform.isLinux [ runc ], # e.g.: runc, gvisor, youki
  # fuse-overlayfs,
  # util-linuxMinimal,
  # nftables,
  # iptables,
  # iproute2,
  catatonit,
  # gvproxy,
  # aardvark-dns,
  # netavark,
  # passt,
  # vfkit,
  # versionCheckHook,
  # writableTmpDirAsHomeHook,
  coreutils,
  # runtimeShell,
  podman,
}:
let
  podman_bin = ./podman/bin;
  podman_conf = ./podman/conf;
in
(podman.override {
  conmon = conmon;
  catatonit = catatonit;
  crun = crun;
}).overrideAttrs
  (oldAttrs: rec {
    propagatedBuildInputs = [ ];
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      btrfs-progs
      gpgme
      libapparmor
      libseccomp
      libselinux
      lvm2
      # systemd
    ];

    nativeInstallCheckInputs = [
      coreutils
    ];

    env = (oldAttrs.env or { }) // {
      HELPER_BINARIES_DIR2 = "/opt/podmanx/libexec/podman";
    };

    patches = [
      (replaceVars ./podman/hardcode-paths.patch {
        bin_path = "/opt/podmanx/libexec/podman";
      })

      # we intentionally don't build and install the helper so we shouldn't display messages to users about it
      ./podman/rm-podman-mac-helper-msg.patch
    ];

    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace Makefile \
        --replace-fail HELPER_BINARIES_DIR HELPER_BINARIES_DIR2
    '';

    postFixup = "";
    postInstall = "
      cp -Lf --remove-destination ${oldAttrs.passthru.helpersBin}/bin/* ${oldAttrs.env.HELPER_BINARIES_DIR}

      mv $out/bin/.podman-wrapped $out/bin/_podman
      rm -f $out/bin/podmansh

      mkdir -p $out/conf
      cp ${podman_bin}/* $out/bin/
      cp ${podman_conf}/* $out/conf/
    ";
  })
