# Design

This document describes the intended design of this repository: what it builds, how the build is wired together, and where to make changes. Keep this document accurate over time: any design-impacting change should update this file.

## Purpose

This repo produces a curated set of mostly-statically-linked (or at least highly portable) tool binaries, built via Nix and published as per-tool archives.

The primary goals are:
- Provide ready-to-use tool binaries for minimal environments (containers, initramfs, scratch-like images, etc.).
- Make builds reproducible and centrally defined (single flake).
- Reduce runtime dependencies by preferring static builds and by normalizing outputs (strip, remove Nix store references in scripts, remove docs/manpages, etc.).

Non-goals:
- Guarantee that every tool is fully static on every platform. Some packages are intentionally non-static (e.g. fonts) and “static” may be best-effort depending on upstream.
- Provide a general-purpose packaging framework beyond what is needed for this repository.

## High-Level Architecture

At a high level, the build pipeline is:
1. Select a set of package derivations (from nixpkgs and/or local overrides).
2. Apply platform-specific adjustments (Linux-only packages; Darwin Go CGO disabling).
3. Wrap each derivation with a “strip/normalize” step to reduce size and remove Nix-specific references.
4. Expose each final derivation as a flake package output.
5. In CI, build each package, package it into a tar.gz, and publish to an OCI registry using `oras`.

The core implementation lives in [flake.nix](file:///workspace/static-binaries/flake.nix).

## Repository Layout

- [flake.nix](file:///workspace/static-binaries/flake.nix): Single source of truth for what gets built and how it gets normalized.
- [pkgs-list/](file:///workspace/static-binaries/pkgs-list): “Manifest” of upstream nixpkgs packages to include.
  - [common.nix](file:///workspace/static-binaries/pkgs-list/common.nix): Shared package list for all platforms.
  - [linux.nix](file:///workspace/static-binaries/pkgs-list/linux.nix): Linux-only additions.
  - [macos.nix](file:///workspace/static-binaries/pkgs-list/macos.nix): macOS-only additions.
- [pkgs/](file:///workspace/static-binaries/pkgs): Local package definitions and overrides.
  - `pkgs/patched/`: Patch/override nixpkgs packages (static flags, hard-coded paths, vendored configs, etc.).
  - `pkgs/wrapped/`: Wrapper derivations and bundled resource layouts.
  - `pkgs/python3/`, `pkgs/pypkgs/`: Python builds and Python-based tools.
- [scripts/patch.sh](file:///workspace/static-binaries/scripts/patch.sh): Normalization script used by the stripping wrapper.
- CI workflows:
  - [build-linux-v2.yaml](file:///workspace/static-binaries/.github/workflows/build-linux-v2.yaml)
  - [build-darwin-v2.yaml](file:///workspace/static-binaries/.github/workflows/build-darwin-v2.yaml)

There is also a [docker/](file:///workspace/static-binaries/docker) directory. It may be an experimental or legacy build path; if it becomes a supported path, document the intended contract here.

## Flake Outputs and Package Selection

### Systems

The flake currently defines outputs for:
- `x86_64-linux`
- `aarch64-darwin`

### Package Sources

`flake.nix` builds the final package set by merging three sources:

1. **Upstream packages (manifest-driven)**  
   The manifest is `pkgs-list/common.nix` merged with `pkgs-list/<platform>.nix`. Each entry maps a name to a small configuration attrset used to pick:
   - `version`: which nixpkgs input to import (`unstable`, `25.11`, `25.05`, `24.11`, `24.05`)
   - `isStatic`: whether to use `pkgsStatic` or regular `pkgs` for that nixpkgs input
   - `output`: list of derivation outputs to expose (`[ "out" ]` by default, sometimes `[ "bin" ]`). The listed outputs are merged with `symlinkJoin`.
   - `alias`: rename the exported flake package

2. **Local packages (`customPkgs`)**  
   Local definitions are built with `callPackage` from files under `pkgs/`. This is where the repo pins special versions (e.g. protobuf) or provides patched/wrapped variants.

3. **Platform-specific additions**
   - On Linux: extra packages and patched tooling (including podman stack, multiple clang-tools versions, static Python variants).
   - On Darwin: for a subset of Go tools, `CGO_ENABLED=0` is set to reduce dynamic library dependence.

### “all” Aggregation Output

In addition to per-package outputs, the flake provides an `all` output using a `linkFarm` over all derivations. This is primarily a convenience for local use and inspection.

## Normalization / Stripping Pipeline

Every derivation in the final package set is wrapped by `stripDrv`, implemented in [flake.nix](file:///workspace/static-binaries/flake.nix). This wrapper:
- Copies the derivation output into a fresh `$out`.
- Makes the output writable.
- Runs [scripts/patch.sh](file:///workspace/static-binaries/scripts/patch.sh) over the output tree.

The current `patch.sh` normalization includes:
- Remove common non-essential directories (`share/man`, `share/doc`, `share/bash-completion`, `nix-support`).
- For text files:
  - Rewrite shebangs from hard-coded Nix store paths to `/usr/bin/env ...` where possible.
  - Remove Nix store path fragments to reduce runtime coupling.
- For ELF binaries:
  - `strip --strip-unneeded` (best-effort).
  - `nuke-refs` to remove Nix store references.
- Rename wrapped executables:
  - Files named like `.*-wrapped` are renamed by removing `-wrapped` and the leading dot.
- Remove `.a` and `.pyc` files.
- Remove symlinks that are broken or point outside of the output prefix.

Design intent: keep runtime payloads small and reduce implicit dependence on the Nix store layout.

## CI / Publishing Model

The CI model is “build each tool independently and publish an artifact per tool”.

### Build selection (Linux)

The Linux workflow uses a two-stage model to avoid spinning up one runner per
package on every change:

1. A `discover` job enumerates all package names dynamically via
   `nix eval .#packages.x86_64-linux --apply builtins.attrNames` (excluding the
   `all` aggregate). It then, for each package, resolves its `outPath` and queries
   the Cachix binary cache with `nix path-info --store <cachix>`. Packages whose
   output is missing from the cache are collected into a GitHub Actions matrix
   (`{"include":[{"name":...}]}`) emitted as a job output.
2. The `build` job consumes that matrix via `fromJSON` and only runs for the
   selected packages. When nothing needs building, the matrix is empty and the
   `build` job is skipped entirely (`if: needs.discover.outputs.count != '0'`).

`workflow_dispatch` with a specific `name` builds only that package; with `*`
(or empty) it forces all packages. `schedule` always forces all packages.

### Artifacts

In both Linux and Darwin workflows:
- The CI job runs `nix build .#<name>`.
- The `./result` output is copied into a directory named after the package via `rsync --copy-unsafe-links`.
- The directory is archived into:
  - `<name>.linux-x86_64.tar.gz` on Linux
  - `<name>.darwin-arm64.tar.gz` on macOS

### Publishing

Workflows publish the tarball to `ghcr.io` using `oras push`, tagged as:
- `ghcr.io/curoky/static-binaries-v3:<name>-linux-x86_64`
- `ghcr.io/curoky/static-binaries-v3:<name>-darwin-arm64`

The flake also configures a Cachix substituter; CI pushes build closures to Cachix to speed up subsequent builds.

## How to Make Changes

### Add a new upstream tool from nixpkgs

1. Add an entry to the appropriate manifest file:
   - Common: `pkgs-list/common.nix`
   - Linux-only: `pkgs-list/linux.nix`
   - macOS-only: `pkgs-list/macos.nix`
2. Decide whether it should use `pkgsStatic` (`isStatic = true`, default) or regular `pkgs` (`isStatic = false`).
3. If the package has multiple outputs, pick the right one(s) via `output = [ "bin" ]` (or list several to merge them).
4. If the nixpkgs attribute name is awkward, use `alias` to export a better public name.
5. Ensure CI includes it in the workflow matrix if it should be published.

### Add a local override / patched build

1. Create a derivation under `pkgs/` (typically `pkgs/patched/` or `pkgs/wrapped/`).
2. Wire it into `customPkgs` or `linux_only` in `flake.nix`.
3. Prefer minimal diffs: only patch what is necessary to improve portability, reduce dynamic deps, or fix runtime paths.

### Change normalization behavior

Edit [scripts/patch.sh](file:///workspace/static-binaries/scripts/patch.sh). Treat this script as a compatibility surface:
- Changing removals/rewrites can break tools in subtle ways.
- Prefer incremental changes and validate on a representative sample of packages.

## Design Documentation Rules

- This file is the design source of truth for the repository.
- Any change that affects architecture, build flow, package selection model, artifact format, or publishing model must update this document in the same change.
