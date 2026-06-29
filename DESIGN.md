# Design

This document describes the intended design of this repository: what it builds, how the build is wired together, and where to make changes. Keep this document accurate over time: any design-impacting change should update this file.

## Purpose

This repo produces a curated set of **standalone, portable** tool binaries, built via Nix and published as per-tool archives.

The primary goals are:
- Provide ready-to-use tool binaries for minimal or foreign environments (containers, initramfs, scratch-like images, etc.).
- Make builds reproducible and centrally defined (single flake).
- Reduce runtime coupling: normalize outputs (strip, remove Nix store references, drop docs/manpages, inline external symlinks) so binaries don't depend on the build host or the Nix store layout.

### Standalone strategy (preference order)

"Standalone" means portable and self-contained — **not** necessarily a single fully static ELF. When deciding how to build a tool, prefer in this order:

1. **Static compilation** where it works (`pkgsStatic`). This remains the default for most packages.
2. **Manual patch + bundle** when full static linking isn't practical: rewrite hard-coded paths, vendor configuration, and bundle required resources (see `packages/`).
3. **`nix bundle`** only as a last resort, for tools that genuinely cannot be statically compiled (e.g. Node.js-based tools). Implemented via `lib/make-bundle.nix` (matthewbauer/nix-bundle); produces a single self-extracting executable and is **Linux only** (relies on user namespaces). Its main downside is that the archive embeds the whole closure into one large file and exposes a single entry point (`meta.mainProgram`), so it cannot ship multiple binaries.

For runtimes that are not statically linkable but are reusable across tools (e.g. a Python interpreter or a JRE), prefer the **shared-sibling wrapper** variant of strategy 2 instead of `nix bundle`: ship the heavy runtime as its own package (e.g. `packages/python/311`, `packages/jre/21`) and give each tool a thin wrapper that resolves the runtime at execution time from the co-located sibling under a shared `$store` parent (e.g. `netron` -> `$store/python311`, `lemminx` -> `$store/jre21`). This keeps tools as ordinary multi-file packages (so they can expose several binaries when needed), shares one runtime across tools instead of duplicating it, and still goes through normal standalone normalization.

Non-goals:
- Guarantee that every tool is a fully static single binary on every platform. Some packages are intentionally non-static (e.g. fonts), and "static" is best-effort depending on upstream.
- Provide a general-purpose packaging framework beyond what this repository needs.

## High-Level Architecture

The build pipeline is:
1. Select upstream package derivations declaratively via per-platform manifests.
2. Merge in locally-defined packages (patched/wrapped/pinned builds) and platform-specific additions.
3. Wrap each derivation with a "standalone normalization" step to slim it down and remove Nix-specific references.
4. Expose each final derivation as a flake package output.
5. In CI, build each package, archive it into a tar.gz, and publish to an OCI registry using `oras`.

The flake is intentionally thin; logic lives in `lib/` and the package definitions live in `manifests/` and `packages/`.

## Repository Layout

- [flake.nix](file:///workspace/static-binaries/flake.nix): Thin entry point. Declares inputs, builds per-system envs, wires helpers, and exposes outputs.
- [lib/](file:///workspace/static-binaries/lib): Reusable build helpers.
  - [make-manifest-packages.nix](file:///workspace/static-binaries/lib/make-manifest-packages.nix): Turns a manifest attrset into a set of upstream nixpkgs derivations.
  - [make-standalone.nix](file:///workspace/static-binaries/lib/make-standalone.nix): Wraps a derivation with the normalization step (runs `scripts/normalize.sh`).
  - [make-bundle.nix](file:///workspace/static-binaries/lib/make-bundle.nix): Bundles a derivation into a single self-extracting executable via `nix bundle` (matthewbauer/nix-bundle), for tools that cannot be statically compiled. Linux only. Bundle outputs skip the standalone normalization step.
- [manifests/](file:///workspace/static-binaries/manifests): Declarative selection of upstream nixpkgs packages.
  - [default.nix](file:///workspace/static-binaries/manifests/default.nix): Single manifest keyed by package name; each entry declares its target `platforms` and optional per-platform config overrides.
- [packages/](file:///workspace/static-binaries/packages): Locally-defined derivations and overrides, organized **one directory per package**.
  - [local.nix](file:///workspace/static-binaries/packages/local.nix): Explicit manifest that aggregates local packages into `{ common; linux; darwin; }` via `callPackage ./<pkg>`.
  - `packages/<pkg>/default.nix`: One directory per local package; the directory also holds that package's own resources (patches, wrapper scripts, vendored configs, e.g. `packages/podman/{bin,conf,*.patch}`, `packages/python/311/Setup.local`).
  - Multi-version applications are grouped under a single application directory with one subdirectory per version: `packages/cmake/{default,3_27_9,4_1_2}`, `packages/python/{311,312,313}`, `packages/clang-tools/{18,19,20,21,22}`, `packages/protobuf/{3_8_0,3_9_2}`. The default/current version of an app lives in `default/`.
  - `packages/protobuf/generic-v3.nix`: A shared builder reused by the protobuf version directories; shared builders are not given their own version subdirectory.
- [scripts/normalize.sh](file:///workspace/static-binaries/scripts/normalize.sh): Output normalization used by the standalone wrapper.
- CI workflows:
  - [build-linux.yaml](file:///workspace/static-binaries/.github/workflows/build-linux.yaml)
  - [build-darwin.yaml](file:///workspace/static-binaries/.github/workflows/build-darwin.yaml)
  - [build-llvm-tools.yaml](file:///workspace/static-binaries/.github/workflows/build-llvm-tools.yaml): dedicated builder for clang-tools / lld (excluded from the main Linux matrix).
  - [build-sbt.yaml](file:///workspace/static-binaries/.github/workflows/build-sbt.yaml): cross-compiles and publishes the Go `sbt` client itself (`sbt-<arch>`).

## Flake Outputs and Package Selection

### Systems

The flake currently defines outputs for:
- `x86_64-linux`
- `aarch64-darwin`

### Per-system environments

`flake.nix` builds one "env" per pinned nixpkgs input (`unstable`, `26.05`, `25.11`, `25.05`, `24.11`, `24.05`). Each env exposes both `pkgs` and `pkgsStatic`. The manifest picks which env + variant a package comes from.

### Package Sources

The final package set merges three sources:

1. **Upstream packages (manifest-driven)** — `lib/make-manifest-packages.nix` applied to `manifests/default.nix` for the current system. Each manifest entry maps a package name to a config attrset:
   - `platforms`: list of systems the package is built for (omitted => all systems).
   - `version`: which nixpkgs env to import (defaults to `unstable`).
   - `isStatic`: use `pkgsStatic` (`true`, default) or regular `pkgs` (`false`).
   - `output`: list of derivation outputs to expose (`[ "out" ]` by default; sometimes `[ "bin" ]`), merged with `symlinkJoin`.
   - `alias`: rename the exported flake package.
   - `bundle`: `nix bundle` the package into a single self-extracting executable instead of normalizing it (Linux only, for tools that cannot be statically compiled). Bundle packages always use regular `pkgs`.
   - `"<system>"`: a per-platform key that overrides any of the fields above (effective config = package-level shared config `//` platform key, platform wins).

2. **Local packages** — `packages/local.nix` returns `{ common; linux; darwin; }`:
   - `common`: cross-platform pinned/patched/wrapped builds (e.g. specific protobuf versions, `coreutils`, vim/zsh/curl wrappers).
   - `linux`: Linux-only patched tooling (podman stack, multiple clang-tools versions, static Python variants, etc.).
   - `darwin`: a subset of Go tools rebuilt with `CGO_ENABLED=0` to reduce dynamic library dependence.

3. **Platform merge** — the flake merges `upstreamPackages // local.common // (local.linux | local.darwin)` depending on the target system.

### "all" Aggregation Output

In addition to per-package outputs, the flake provides an `all` output using a `linkFarm` over all standalone derivations. This is a convenience for local use and inspection.

## Standalone Normalization Pipeline

Every derivation in the final package set is wrapped by `make-standalone.nix`, which:
- Copies the derivation output into a fresh, writable `$out`.
- Runs [scripts/normalize.sh](file:///workspace/static-binaries/scripts/normalize.sh) over the output tree.

Bundle packages (`bundle = true` in the manifest) are the exception: they are produced by `make-bundle.nix` as a single self-extracting executable and skip normalization entirely (stripping / nuke-refs / shebang rewriting would corrupt the archive).

This wrapper is purely post-processing; it does not change how a package is compiled (static vs dynamic). The normalization in `normalize.sh` includes:
- Remove non-essential directories (`share/man`, `share/doc`, `share/bash-completion`, `nix-support`).
- Resolve symlinks: keep links pointing inside `$out`; inline (copy) the real file for links pointing outside (e.g. into `/nix/store`) so the payload stays self-contained; drop dangling links.
- For text files: rewrite shebangs from hard-coded Nix store paths to `/usr/bin/env ...`; strip Nix store path fragments.
- For ELF binaries: `strip --strip-unneeded` (best-effort) and `nuke-refs`.
- Rename `.*-wrapped` executables by removing the `-wrapped` suffix and leading dot.
- Remove `.a` and `.pyc` files.

Design intent: keep runtime payloads small and remove implicit dependence on the Nix store layout.

## CI / Publishing Model

The CI model is "build each tool independently and publish an artifact per tool".

### Build selection (Linux)

The Linux workflow uses a two-stage model to avoid spinning up one runner per package on every change:

1. A `discover` job enumerates all package names via `nix eval .#packages.x86_64-linux` (excluding the `all` aggregate), resolves each package's `outPath`, and queries the Cachix binary cache with `nix path-info --store <cachix>`. Packages missing from the cache form a GitHub Actions matrix emitted as a job output. Packages in `EXCLUDE_PKGS` (built by dedicated workflows) are filtered out.
2. The `build` job consumes that matrix via `fromJSON` and runs only for selected packages. When nothing needs building, the `build` job is skipped (`if: needs.discover.outputs.count != '0'`).

`workflow_dispatch` with a specific `name` builds only that package; with `*` (or empty) it forces all packages. `schedule` always forces all packages.

### Artifacts

In both Linux and Darwin workflows:
- The CI job runs `nix build .#<name>`.
- The `./result` output is copied into a directory named after the package via `rsync --copy-unsafe-links`.
- The directory is archived into:
  - `<name>.linux-x86_64.tar.gz` on Linux
  - `<name>.darwin-arm64.tar.gz` on macOS

### Publishing

Workflows publish the tarball to `ghcr.io` using `oras push`, tagged as:
- `ghcr.io/curoky/static-binaries-v4:<name>-linux-x86_64`
- `ghcr.io/curoky/static-binaries-v4:<name>-darwin-arm64`

The flake also configures a Cachix substituter; CI pushes build closures to Cachix to speed up subsequent builds.

## Client Install / Upgrade Model (`tools/sbt`)

[tools/sbt](file:///workspace/static-binaries/tools/sbt) is a small package manager (a brew/apt-style client) for **minimal environments that have no Nix/Homebrew/package manager**. It is written in **Go** as a single, statically-linked binary, cross-compiled for `linux-x86_64` and `darwin-arm64`. It pulls the published tarballs straight from the `ghcr.io/curoky/static-binaries-v4` OCI registry (reusing the `<name>-<arch>` tag -> layer blob digest flow described above) and installs them locally.

### Design principles

- **No host runtime dependencies.** sbt is one static binary built with `CGO_ENABLED=0`; **nothing** (`curl`/`tar`/`oras`/`jq`/Nix) is needed on the target host. It leans on well-maintained Go libraries rather than hand-rolled plumbing: [go-containerregistry](https://github.com/google/go-containerregistry) (`crane`) for all OCI access (auth, manifest, layer pull, digest), [cobra](https://github.com/spf13/cobra) for the CLI, and [`x/sync/errgroup`](https://pkg.go.dev/golang.org/x/sync/errgroup) for bounded-parallel fan-out. Tarball extraction uses the standard library (`archive/tar` + `compress/gzip`). The same source cross-compiles to both platforms.
- **Relocatable installs.** Everything a package exposes under the prefix is a **relative** symlink. Because links are relative, the entire prefix can be moved anywhere with **zero repair**.
- **Independent packages.** Every package is treated as fully self-contained; sbt does **no dependency resolution**. Each package is installed, removed, and relocated on its own. Runtime-heavy packages (node/python/perl tools) carry their own relative-path wrappers, so an individual `store/<name>/` directory is self-contained as well.
- **Platforms.** Auto-detected arch tag is `linux-x86_64` (Linux/x86_64) or `darwin-arm64` (macOS/arm64), matching the published OCI tags; override with `--arch`.
- **Self-publishing.** sbt is itself published to the registry as `sbt-<arch>` by [build-sbt.yaml](file:///workspace/static-binaries/.github/workflows/build-sbt.yaml), so it can be bootstrapped with a single `curl` and afterwards upgraded like any other package.

### Source layout

[tools/sbt](file:///workspace/static-binaries/tools/sbt) is a Go module:
- [main.go](file:///workspace/static-binaries/tools/sbt/main.go): the entire client (OCI access, store/meta/link, commands, CLI).
- [main_test.go](file:///workspace/static-binaries/tools/sbt/main_test.go): offline unit tests (tar extraction + relative-link relocation + arg parsing + metadata round-trip).

### Local layout

Packages are installed under a prefix (default `/opt/sbt`):

- `store/<name>/`: the extracted package contents.
- `store/<name>/.sbt-meta`: per-package metadata, kept **inside** the package directory so it is created and removed atomically with the package. It is a plain `key=value` file (`name`, `arch`, `digest`, `linked`, `installed_at`).
- `bin/`, `lib/`, `share/`, ...: when installed with `--link` (default), **relative** symlinks into `store/<name>/` (the `.sbt-meta` file is excluded from linking). `--nolink` installs into the store only.

### Upgrade semantics (digest comparison)

There is no human-readable version embedded in the OCI tag (`<name>-<arch>`), so "needs update" is decided by **OCI blob digest comparison**: the client resolves the remote manifest's layer digest and compares it against the `digest` recorded in the local `.sbt-meta`. If they differ, the package is re-downloaded and re-extracted; otherwise it is skipped (`install` is idempotent unless `--force` is given).

### Subcommands

- `install <pkg>...`: install/refresh **one or more** packages; skips packages whose local digest already matches the remote (override with `--force`). `--link`/`--nolink` control symlink exposure. Multi-package installs run in three phases: (1) resolve every package's remote digest **in parallel** — if any package is missing, sbt aborts with the full list and installs nothing; (2) download the needed blobs **in parallel** into the cache; (3) extract + link **serially**.
- `remove <pkg>`: remove a package's symlinks (when linked) and delete its `store/<name>/` directory.
- `upgrade [pkg...]`: upgrade the given packages, or all installed packages when none is given (reuses the install digest-skip logic, preserving each package's recorded arch/linked).
- `info <pkg>`: show a package's recorded metadata (or its registry coordinates if not installed) and whether it is up to date vs. the remote digest.
- `list`: list installed packages and their recorded digests by reading each `store/*/.sbt-meta`.
- `outdated`: report installed packages whose remote digest has changed.

Common options: `--prefix PATH|--prefix=PATH` and `--arch ARCH|--arch=ARCH` (both `--opt value` and `--opt=value` forms accepted; options may appear before or after the package names).

This is a client-only concern: the CI/publishing model above is unchanged, because the comparison relies on the layer digest that `ghcr.io` already computes during `oras push`.

## How to Make Changes

### Add a new upstream tool from nixpkgs

1. Add an entry to [manifests/default.nix](file:///workspace/static-binaries/manifests/default.nix):
   - Omit `platforms` for an all-platform package, or set `platforms = [ "x86_64-linux" ]` / `[ "aarch64-darwin" ]` to restrict it.
   - For a package that exists everywhere but needs a different config per system, add a per-platform key, e.g. `aria2 = { "aarch64-darwin" = { version = "24.11"; }; };`.
2. Decide whether it should use `pkgsStatic` (`isStatic = true`, default) or regular `pkgs` (`isStatic = false`).
3. If the package has multiple outputs, pick the right one(s) via `output = [ "bin" ]` (or list several to merge them).
4. If the nixpkgs attribute name is awkward, use `alias` to export a better public name.
5. If the tool cannot be statically compiled, prefer the shared-sibling wrapper approach over `nix bundle`: ship it as a local package whose JS/runtime is reused from upstream and wrapped to invoke the co-located static `nodejs-slim24` sibling (see `pnpm`, `prettier`, `markdownlint-cli2`, `opencommit` under "local override", below). Use `bundle = true` (with `isStatic = false` and `platforms = [ "x86_64-linux" ]`) only as a true last resort for tools that have no reusable sibling runtime.

### Add a local override / patched build

1. Create a directory `packages/<pkg>/` with a `default.nix`, plus any resources (patches, wrapper scripts, vendored configs) the package needs alongside it.
2. Wire it into the appropriate set in `packages/local.nix` (`common`, `linux`, or `darwin`) via `callPackage ./<pkg> { }`. `local.nix` remains the explicit manifest of local packages (no auto-discovery).
3. Follow the standalone strategy: prefer static; otherwise patch + bundle; use `nix bundle` only when static is impossible.
4. Prefer minimal diffs: only patch what is necessary to improve portability, reduce dynamic deps, or fix runtime paths.

Example — Node.js tools (`packages/pnpm`, `packages/prettier`, `packages/markdownlint-cli2`, `packages/opencommit`): instead of `nix bundle`, each reuses the tool's JS distribution (`lib/node_modules/<pkg>`) and replaces the upstream bin wrapper(s) with a relative-path script that invokes the sibling static node (`$store/nodejs-slim24/bin/node`) explicitly, so the static node travels with the deployed tool instead of depending on a node on the host PATH after the standalone normalize pass. `pnpm`/`prettier` are additionally *built* against the static node by overriding the upstream interpreter (`pnpm` only unpacks JS; `prettier` fetches deps with pnpm), which exercises the static runtime end-to-end. `markdownlint-cli2`/`opencommit` are npm-based `buildNpmPackage` tools whose build needs `npm` (absent from `nodejs-slim`), so they are built with the regular node and only switch to the sibling static node at runtime. This supersedes the previous `bundle = true` entries for these tools in the manifest.

### Change normalization behavior

Edit [scripts/normalize.sh](file:///workspace/static-binaries/scripts/normalize.sh). Treat this script as a compatibility surface:
- Changing removals/rewrites can break tools in subtle ways.
- Prefer incremental changes and validate on a representative sample of packages.

## Design Documentation Rules

- This file is the design source of truth for the repository.
- Any change that affects architecture, build flow, package selection model, artifact format, or publishing model must update this document in the same change.
