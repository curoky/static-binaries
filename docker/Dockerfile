# syntax=docker/dockerfile:1.9.0
FROM nixpkgs/nix-unstable:nixos-25.11-x86_64-linux AS nixpkgs-builder

ENV NIX_PATH=nixpkgs=channel:nixos-25.11 \
  NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 \
  PATH=$PATH:/nix/var/nix/profiles/packer/bin

RUN nix-channel --add https://nixos.org/channels/nixos-25.11 nixpkgs \
  && nix-channel --update \
  && nix-env -p /nix/var/nix/profiles/packer -iA nixpkgs.python3 nixpkgs.go-task \
    nixpkgs.gnused nixpkgs.gnutar nixpkgs.findutils nixpkgs.file nixpkgs.gnugrep \
    nixpkgs.binutils

ARG PACKAGE_NAME=curl
ARG ARCH_NAME=linux-x86_64

WORKDIR /root
COPY . .

RUN task -t tasks/${ARCH_NAME}/Taskfile.yaml setup
RUN task -t tasks/${ARCH_NAME}/Taskfile.yaml ${PACKAGE_NAME}
RUN ./scripts/pack.py
RUN ./scripts/patch.sh ${PACKAGE_NAME} /root/tmp/output
RUN cd tmp \
  && mv output ${PACKAGE_NAME} \
  && tar -czvf /tmp/${PACKAGE_NAME}.${ARCH_NAME}.tar.gz ${PACKAGE_NAME}
