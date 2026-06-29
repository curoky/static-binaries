# Standalone Binaries

This repository hosts a collection of **standalone, portable tool binaries** built
with Nix. The goal is binaries you can drop into a minimal or foreign
environment and run, without installing extra runtime dependencies.

## 🚀 Goals

- **Portability**: run on almost any Linux distribution (Ubuntu, Alpine, CentOS, etc.)
  and on macOS, without manual dependency setup.
- **Minimal runtime coupling**: prefer self-contained payloads; strip binaries
  and remove Nix store references so they don't depend on the build host.
- **Instant use**: ideal for debugging containers, minimal environments, initramfs,
  or quick deployment.

### Standalone strategy

"Standalone" means portable and self-contained — not necessarily a single fully
static ELF. The order of preference is:

1. **Static compilation** where it works (via `pkgsStatic`).
2. **Manual patch + bundle** when full static linking isn't practical (rewrite
   hard-coded paths, vendor configs, bundle required resources).
3. **`nix bundle`** only as a last resort for tools that genuinely cannot be
   statically compiled (e.g. Node.js-based tools).

## 📥 Download

Prebuilt artifacts are published per-tool to an OCI registry
(`ghcr.io/curoky/standalone-binaries`) and on the GitHub Releases page.

### Release v1.0

Access the assets for version `v1.0` directly here:
> **https://github.com/curoky/standalone-binaries/releases/tag/v1.0**

## 📂 Repository Layout

See [DESIGN.md](./DESIGN.md) for the full architecture. In short:

- `flake.nix` — thin entry point wiring inputs, helpers, and outputs.
- `lib/` — reusable build helpers (manifest package selection, standalone normalization).
- `manifests/` — declarative selection of upstream nixpkgs packages.
- `packages/` — locally defined patched / wrapped / pinned builds.
- `scripts/normalize.sh` — output normalization (strip, de-reference, slim down).
