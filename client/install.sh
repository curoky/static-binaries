#!/usr/bin/env bash

# Bootstrap installer for the `sb` client.
#
# `sb` is published as an OCI artifact at ghcr.io/curoky/standalone-binaries
# under the tag `sb-<arch>` (a single .tar.gz layer containing ./sb/sb). On a
# fresh, minimal host there is no oras/go/nix, only curl + tar, so this script
# pulls the layer blob directly over the ghcr registry HTTP API and drops the
# `sb` binary onto PATH. Afterwards `sb` self-upgrades like any other package.
#
# Usage:
#   curl -fsSL <raw-url>/install.sh | bash
#   curl -fsSL <raw-url>/install.sh | bash -s -- --prefix /usr/local/bin
#
# Overrides (env or flag, flag wins):
#   SB_INSTALL_DIR / --prefix DIR   install directory (default: ~/.local/bin)
#   SB_ARCH        / --arch ARCH    arch tag: linux-x86_64 | darwin-arm64
set -euo pipefail

REGISTRY="ghcr.io"
REPOSITORY="curoky/standalone-binaries"

INSTALL_DIR="${SB_INSTALL_DIR:-$HOME/.local/bin}"
ARCH="${SB_ARCH:-}"

die() {
  echo "error: $*" >&2
  exit 1
}

# Parse flags (allow `bash -s -- --prefix ... --arch ...`).
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix | --prefix=*)
      if [ "$1" = "--prefix" ]; then
        INSTALL_DIR="$2"
        shift 2
      else
        INSTALL_DIR="${1#*=}"
        shift
      fi
      ;;
    --arch | --arch=*)
      if [ "$1" = "--arch" ]; then
        ARCH="$2"
        shift 2
      else
        ARCH="${1#*=}"
        shift
      fi
      ;;
    -h | --help)
      sed -n '18,32p' "$0" 2>/dev/null || true
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v tar >/dev/null 2>&1 || die "tar is required"

# Detect the publish arch tag, mirroring detectArch() in main.go. Only
# linux-x86_64 and darwin-arm64 are published; anything else must use --arch.
if [ -z "$ARCH" ]; then
  os="$(uname -s)"
  machine="$(uname -m)"
  case "$os/$machine" in
    Linux/x86_64 | Linux/amd64) ARCH="linux-x86_64" ;;
    Darwin/arm64 | Darwin/aarch64) ARCH="darwin-arm64" ;;
    *) die "unsupported platform $os/$machine; pass --arch linux-x86_64 or darwin-arm64" ;;
  esac
fi

TAG="sb-$ARCH"
echo "> Installing sb ($ARCH) into $INSTALL_DIR"

# 1. Anonymous pull token for ghcr.
token="$(curl -fsSL \
  "https://${REGISTRY}/token?scope=repository:${REPOSITORY}:pull" |
  tr ',' '\n' | grep -o '"token":"[^"]*"' | head -n1 | cut -d'"' -f4)"
[ -n "$token" ] || die "failed to obtain registry token"

# 2. Resolve the manifest and pull out the single layer digest.
manifest="$(curl -fsSL \
  -H "Authorization: Bearer ${token}" \
  -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "https://${REGISTRY}/v2/${REPOSITORY}/manifests/${TAG}")"

# The artifact has one content layer; take the last digest in the layers array.
digest="$(printf '%s' "$manifest" |
  tr ',' '\n' | grep -o '"digest":"sha256:[a-f0-9]*"' | tail -n1 | cut -d'"' -f4)"
[ -n "$digest" ] || die "could not find layer digest for $TAG (is it published?)"

# 3. Stream the blob into a temp dir, then move the sb binary into place. The
# archive layout is ./sb/sb; extracting to a tmp dir avoids tar member-match
# quirks (leading "./", matching the dir as well as the file).
mkdir -p "$INSTALL_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL \
  -H "Authorization: Bearer ${token}" \
  "https://${REGISTRY}/v2/${REPOSITORY}/blobs/${digest}" |
  tar -xz -C "$tmp"
[ -f "$tmp/sb/sb" ] || die "archive did not contain sb/sb"
mv -f "$tmp/sb/sb" "$INSTALL_DIR/sb"

chmod +x "$INSTALL_DIR/sb"

echo "> Installed: $INSTALL_DIR/sb"

# A failing self-check below must not change the installer's exit status: the
# binary is already in place. Probe it, but always report success for the
# install itself.
if "$INSTALL_DIR/sb" --help >/dev/null 2>&1; then
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) echo "> sb is on PATH and ready." ;;
    *)
      echo "> Note: $INSTALL_DIR is not on PATH. Add it, e.g.:"
      echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
      ;;
  esac
else
  echo "> Warning: $INSTALL_DIR/sb was installed but could not be executed here" >&2
  echo "  (possible noexec mount or libc mismatch). Try running it directly." >&2
fi

exit 0
