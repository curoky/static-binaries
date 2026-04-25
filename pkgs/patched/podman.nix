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
  # coreutils,
  # runtimeShell,
  podman,
}:
(podman.override {
  conmon = conmon;
  catatonit = catatonit;
  crun = crun;
}).overrideAttrs
  (oldAttrs: rec {
    propagatedBuildInputs = [ ];
    env = (oldAttrs.env or { }) // {
      HELPER_BINARIES_DIR = "/opt/podman/libexec/podman";
    };
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      btrfs-progs
      gpgme
      libapparmor
      libseccomp
      libselinux
      lvm2
      # systemd
    ];

    patches = [
      (replaceVars ./podman/hardcode-paths.patch {
        bin_path = "/opt/podman/libexec/podman";
      })

      # we intentionally don't build and install the helper so we shouldn't display messages to users about it
      ./podman/rm-podman-mac-helper-msg.patch
    ];

    postFixup = "";

    postInstall = "
      cp -Lf --remove-destination ${oldAttrs.passthru.helpersBin}/bin/* ${oldAttrs.env.HELPER_BINARIES_DIR}
    ";
  })
