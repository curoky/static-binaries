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

#### Portability requirement (the hard rule)

The shipped binary must be portable and **must not depend on any dynamic library under `/nix`**.

- **Linux:** full static is the goal (`pkgsStatic`).
- **macOS:** full static is impossible (no static libSystem/libc), so the goal is: **every nix dependency statically linked; only macOS system libraries (e.g. `/usr/lib/libSystem.B.dylib`) may stay dynamic.** Apply this ladder:
  1. Full static where it works (`pkgsStatic`) — sometimes needs small upstream patches to make a static link succeed on darwin (e.g. `packages/krb5/darwin.nix` builds the fully-static `pkgsStatic.krb5` but disables the macOS CCAPI ccache backend and moves a DES const definition so static archive linking of `libkrb5.a`/`libk5crypto.a` resolves; the result depends only on `/usr/lib/libSystem`).
  2. Otherwise, link every other dependency statically; let only system libs stay dynamic.
  3. Copy the dylibs (the dylib-bundle variant below) only when a dependency cannot be statically linked — **requires explicit confirmation**.

If a build retains `/nix/store` dylibs, fix it (`CGO_ENABLED=0`, patch install names / rpaths, or — with confirmation — copy the dylib).

For strategy 2, when the darwin `pkgsStatic` set would only drag in a separate static toolchain (no real static-libc payoff) but the tool has just one or two non-system dynamic deps, a lighter variant is: build from the **native `pkgs`** derivation (prebuilt in the upstream cache, no local toolchain build) and inject only that dependency's static archive (e.g. `pkgs.perl.override { libxcrypt = pkgsStatic.libxcrypt; }`), then rewrite any remaining `/nix/store` Mach-O install names to `@loader_path`-relative paths in the package's `postInstall` (`normalize.sh` does not touch Mach-O load commands). This keeps the result depending only on `/usr/lib` system libs and relocatable. `packages/perl` uses this on darwin while staying fully static via `pkgsStatic` on Linux. `packages/wget` is fully static via `pkgsStatic` on both platforms: on Linux straight from the set (`./wget/default.nix`), on darwin from `pkgsStatic.wget` with only its *build-time* `perlPackages` overridden to the native set (`./wget/darwin-static.nix`) — the darwin `pkgsStatic.perl` itself fails to build (its final `mktables` step crashes the freshly built static miniperl, which has most locale support compiled out), and wget needs perl only as a build tool. A dependency-by-dependency variant that instead builds native `pkgs.wget` and swaps each non-system dep for its `pkgsStatic` archive is kept as an alternative in `./wget/darwin.nix`.

For a feature-rich tool whose darwin `pkgsStatic` build fails only because *some* optional feature libraries cannot build or link statically, another strategy-2 variant is **feature reduction**: start from the `pkgsStatic.<tool>` derivation and disable just the offending features via `.override`, keeping every codec/library whose static archive links cleanly. `packages/ffmpeg/darwin.nix` does this on top of `pkgsStatic.ffmpeg-headless`: the full `pkgsStatic.ffmpeg` is unbuildable on aarch64-darwin (dav1d/opus/etc. static builds hit a meson `arm64` cross-file bug; zimg/vid-stab/OpenCL pull in `openmp` -> `llvm-static`, which fails at CheckAtomic/libatomic; `libopenmpt` drags in an autogen step that gets SIGKILLed), so those features are turned off (`withDav1d`/`withOpus`/`withZimg`/... = false). Disabling every `openmp` path also keeps `nix eval` clean without a `config.problems` handler (openmp is the only thing that would mark the darwin static `python3` broken). `withOpenapv` is off because `liboapv` ships only a `.dylib` even under `pkgsStatic` (it would leave a `/nix/store` load command); the network/TLS libs (gnutls/ssh/srt/rist) are off because they fail ffmpeg's static configure link test. `x265` is kept but needs two package fixes (drop its `postInstall` `rm -f $out/lib/*.a`, which under `pkgsStatic`/`ENABLE_SHARED=false` would delete the only artifact `libx265.a`; and `multibitdepthSupport = false` to avoid undefined `x265_1{0,2}bit::` symbols in the static archive — trade-off: 8-bit HEVC encode only). The result depends only on `/usr/lib/*` and `/System/Library/Frameworks/*`.

For runtimes that are not statically linkable but are reusable across tools (e.g. a Python interpreter), prefer the **shared-sibling wrapper** variant of strategy 2 instead of `nix bundle`: ship the heavy runtime as its own package (e.g. `packages/python/311`) and give each tool a thin wrapper that resolves the runtime at execution time from the co-located sibling under a shared `$store` parent (e.g. `netron` -> `$store/python311`). This keeps tools as ordinary multi-file packages (so they can expose several binaries when needed), shares one runtime across tools instead of duplicating it, and still goes through normal standalone normalization.

Perl tools follow this sibling-wrapper convention against the shared `packages/perl`: the tool's bin is renamed (e.g. `exiftool` -> `_exiftool`) and replaced with a wrapper that runs `$store/perl/bin/perl` on it with `PERL5LIB` pointing at the tool's bundled `lib/perl5` modules (`cloc`, `exiftool`). Handling XS (compiled) Perl deps is **platform-split**, because the two `packages/perl` builds differ: the Linux `perl` is fully static (`pkgsStatic`, built `-Uusedl`) and therefore **cannot `dlopen` any XS `.so` at runtime**, while the darwin `perl` is native and can. So `packages/exiftool` splits into `default.nix` (Linux) and `darwin.nix`:
- **Linux (`packages/exiftool/default.nix`):** the optional compression XS modules must be compiled **into** the static interpreter as static extensions. Upstream `pkgsStatic.perl` already vendors `Compress::Raw::{Zlib,Bzip2}` and the `IO::Compress::*` family; `packages/perl/default.nix` additionally injects the two missing XS dists (`Compress::Raw::Lzma`, `IO::Compress::Brotli`) under `cpan/` (with a `config.in` pointing Lzma at static `xz` and a minimal `Makefile.PL` linking the static `brotli` archives, plus MANIFEST entries) so perl's own build harness links `liblzma`/`libbrotli` straight into the `perl` binary. exiftool then ships only pure-Perl pieces (its script, `Image::ExifTool`, pure-Perl `Archive::Zip`) — no `.so` at all.
- **darwin (`packages/exiftool/darwin.nix`):** the native perl can load `.bundle`s, so apply strategy 2 to each XS module — re-point the module's nixpkgs build at the matching `pkgsStatic.<lib>` lib dir (which ships only a `.a`) so the compression lib links statically and the resulting `.bundle` depends only on `/usr/lib` system libs (`Compress::Raw::{Zlib,Bzip2,Lzma}`, `IO::Compress::Brotli` -> static `zlib`/`bzip2`/`xz`/`brotli`), avoiding any dylib copy.

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

- [flake.nix](file:///workspace/standalone-binaries/flake.nix): Thin entry point. Declares inputs, builds per-system envs, wires helpers, and exposes outputs.
- [lib/](file:///workspace/standalone-binaries/lib): Reusable build helpers.
  - [make-manifest-packages.nix](file:///workspace/standalone-binaries/lib/make-manifest-packages.nix): Turns a manifest attrset into a set of upstream nixpkgs derivations.
  - [make-standalone.nix](file:///workspace/standalone-binaries/lib/make-standalone.nix): Wraps a derivation with the normalization step (runs `scripts/normalize.sh`).
  - [make-bundle.nix](file:///workspace/standalone-binaries/lib/make-bundle.nix): Bundles a derivation into a single self-extracting executable via `nix bundle` (matthewbauer/nix-bundle), for tools that cannot be statically compiled. Linux only. Bundle outputs skip the standalone normalization step.
- [manifests/](file:///workspace/standalone-binaries/manifests): Declarative selection of upstream nixpkgs packages.
  - [default.nix](file:///workspace/standalone-binaries/manifests/default.nix): Single manifest keyed by package name; each entry declares its target `platforms` and optional per-platform config overrides.
- [packages/](file:///workspace/standalone-binaries/packages): Locally-defined derivations and overrides, organized **one directory per package**.
  - [local.nix](file:///workspace/standalone-binaries/packages/local.nix): Explicit manifest that aggregates local packages into `{ common; linux; darwin; }` via `callPackage ./<pkg>`.
  - `packages/<pkg>/default.nix`: One directory per local package; the directory also holds that package's own resources (patches, wrapper scripts, vendored configs, e.g. `packages/podman/{bin,conf,*.patch}`, `packages/python/311/Setup.local`).
  - Multi-version applications are grouped under a single application directory with one subdirectory per version: `packages/cmake/{default,3_27_9,4_1_2}`, `packages/python/{311,312,313}`, `packages/clang-tools/{18,19,20,21,22}`, `packages/protobuf/{3_8_0,3_9_2}`. The default/current version of an app lives in `default/`.
  - `packages/protobuf/generic-v3.nix`: A shared builder reused by the protobuf version directories; shared builders are not given their own version subdirectory.
- [scripts/normalize.sh](file:///workspace/standalone-binaries/scripts/normalize.sh): Output normalization used by the standalone wrapper.
- CI workflows:
  - [build-linux.yaml](file:///workspace/standalone-binaries/.github/workflows/build-linux.yaml)
  - [build-darwin.yaml](file:///workspace/standalone-binaries/.github/workflows/build-darwin.yaml)
  - [build-llvm-tools.yaml](file:///workspace/standalone-binaries/.github/workflows/build-llvm-tools.yaml): dedicated builder for clang-tools / lld (excluded from the main Linux matrix).
  - [build-sb.yaml](file:///workspace/standalone-binaries/.github/workflows/build-sb.yaml): cross-compiles and publishes the Go `sb` client itself (`sb-<arch>`).

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
   - `darwin`: a subset of Go tools rebuilt with `CGO_ENABLED=0` to reduce dynamic library dependence, plus `nodejs-slim26` (a mostly-static Node.js 26 — see below).

3. **Platform merge** — the flake merges `upstreamPackages // local.common // (local.linux | local.darwin)` depending on the target system.

### "all" Aggregation Output

In addition to per-package outputs, the flake provides an `all` output using a `linkFarm` over all standalone derivations. This is a convenience for local use and inspection.

## Standalone Normalization Pipeline

Every derivation in the final package set is wrapped by `make-standalone.nix`, which:
- Copies the derivation output into a fresh, writable `$out`.
- Runs [scripts/normalize.sh](file:///workspace/standalone-binaries/scripts/normalize.sh) over the output tree.

Bundle packages (`bundle = true` in the manifest) are the exception: they are produced by `make-bundle.nix` as a single self-extracting executable and skip normalization entirely (stripping / nuke-refs / shebang rewriting would corrupt the archive).

This wrapper is purely post-processing; it does not change how a package is compiled (static vs dynamic). The normalization in `normalize.sh` includes:
- Remove non-essential directories (`share/man`, `share/doc`, `share/bash-completion`, `nix-support`).
- Resolve symlinks: keep links pointing inside `$out`; inline (copy) the real file for links pointing outside (e.g. into `/nix/store`) so the payload stays self-contained; drop dangling links.
- For text files: rewrite shebangs from hard-coded Nix store paths to `/usr/bin/env ...`; strip Nix store path fragments.
- For ELF binaries: `strip --strip-unneeded` (best-effort) and `nuke-refs`.
- Rename `.*-wrapped` executables by removing the `-wrapped` suffix and leading dot.
- Remove `.a` and `.pyc` files.
- **Final portability check (the hard rule):** walk every ELF (Linux) / Mach-O (Darwin) file, print its dynamic dependencies (`patchelf --print-needed` + `--print-rpath` on Linux, `otool -L` on Darwin — the tools are added to the standalone wrapper's `nativeBuildInputs` per platform in `make-standalone.nix`), and **fail the build** if any dependency (or ELF rpath) resolves under `/nix`. This enforces "the shipped binary must not depend on any dynamic library under `/nix`" at build time. `otool -L`'s first line is the file's own path (under the `/nix/store` output dir) and is skipped before matching.

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
- `ghcr.io/curoky/standalone-binaries:<name>-linux-x86_64`
- `ghcr.io/curoky/standalone-binaries:<name>-darwin-arm64`

The flake also configures a Cachix substituter; CI pushes build closures to Cachix to speed up subsequent builds.

## Client Install / Upgrade Model (`client/`)

[client/](file:///workspace/standalone-binaries/client) is a small package manager (a brew/apt-style client) for **minimal environments that have no Nix/Homebrew/package manager**. It is written in **Go** as a single, statically-linked binary (`sb`), cross-compiled for `linux-x86_64` and `darwin-arm64`. It pulls the published tarballs straight from the `ghcr.io/curoky/standalone-binaries` OCI registry (reusing the `<name>-<arch>` tag -> layer blob digest flow described above) and installs them locally.

### Design principles

- **No host runtime dependencies.** sb is one static binary built with `CGO_ENABLED=0`; **nothing** (`curl`/`tar`/`oras`/`jq`/Nix) is needed on the target host. It leans on well-maintained Go libraries rather than hand-rolled plumbing: [go-containerregistry](https://github.com/google/go-containerregistry) (`crane`) for all OCI access (auth, manifest, layer pull, digest), [cobra](https://github.com/spf13/cobra) for the CLI, [`x/sync/errgroup`](https://pkg.go.dev/golang.org/x/sync/errgroup) for bounded-parallel fan-out, and [mpb](https://github.com/vbauerster/mpb) for concurrent download progress bars. Tarball extraction uses the standard library (`archive/tar` + `compress/gzip`). The same source cross-compiles to both platforms.
- **Relocatable installs.** Everything a package exposes under the prefix is a **relative** symlink. Because links are relative, the entire prefix can be moved anywhere with **zero repair**.
- **Independent packages.** Every package is treated as fully self-contained; sb does **no dependency resolution**. Each package is installed, removed, and relocated on its own. Runtime-heavy packages (node/python/perl tools) carry their own relative-path wrappers, so an individual `store/<name>/` directory is self-contained as well.
- **Platforms.** Auto-detected arch tag is `linux-x86_64` (Linux/x86_64) or `darwin-arm64` (macOS/arm64), matching the published OCI tags; override with `--arch`.
- **Self-publishing.** sb is itself published to the registry as `sb-<arch>` by [build-sb.yaml](file:///workspace/standalone-binaries/.github/workflows/build-sb.yaml), so it can be bootstrapped with a single `curl` and afterwards upgraded like any other package.

### Source layout

[client/](file:///workspace/standalone-binaries/client) is a Go module:
- [main.go](file:///workspace/standalone-binaries/client/main.go): the entire client (OCI access, store/meta/link, commands, CLI).
- [main_test.go](file:///workspace/standalone-binaries/client/main_test.go): offline unit tests (tar extraction + relative-link relocation + arg parsing + metadata round-trip).
- [install.sh](file:///workspace/standalone-binaries/client/install.sh): the **bootstrap installer** for `sb` itself. On a fresh host there is no `oras`/Go/Nix, only `curl` + `tar`, so it cannot use `sb` to install `sb`. It pulls the `sb-<arch>` artifact straight over the ghcr registry HTTP API (anonymous pull token -> manifest -> single layer blob), extracts `sb/sb`, and drops the binary into the install dir (default `~/.local/bin`; override via `SB_INSTALL_DIR`/`--prefix` and `SB_ARCH`/`--arch`). Intended to be run as `curl -fsSL <raw-url>/install.sh | bash`. After this one-shot bootstrap, `sb` upgrades itself like any other package.

### Local layout

Packages are installed under a prefix (default `/opt/sb`):

- `store/<name>/`: the extracted package contents.
- `store/<name>/.sb-meta`: per-package metadata, kept **inside** the package directory so it is created and removed atomically with the package. It is a plain `key=value` file (`name`, `arch`, `digest`, `linked`, `installed_at`).
- `bin/`, `lib/`, `share/`, ...: when installed with `--link` (default), **relative** symlinks into `store/<name>/` (the `.sb-meta` file is excluded from linking). `--nolink` installs into the store only.

### Upgrade semantics (digest comparison)

There is no human-readable version embedded in the OCI tag (`<name>-<arch>`), so "needs update" is decided by **OCI blob digest comparison**: the client resolves the remote manifest's layer digest and compares it against the `digest` recorded in the local `.sb-meta`. If they differ, the package is re-downloaded and re-extracted; otherwise it is skipped (`install` is idempotent unless `--force` is given).

### Subcommands

- `install <pkg>...`: install/refresh **one or more** packages; skips packages whose local digest already matches the remote (override with `--force`). `--link`/`--nolink` control symlink exposure. Multi-package installs run in three phases: (1) resolve every package's remote digest **in parallel** — if any package is missing, sb aborts with the full list and installs nothing; (2) download the needed blobs **in parallel** into the cache; (3) extract + link **serially**.
- `remove <pkg>`: remove a package's symlinks (when linked) and delete its `store/<name>/` directory.
- `upgrade [pkg...]`: upgrade the given packages, or all installed packages when none is given (reuses the install digest-skip logic, preserving each package's recorded arch/linked).
- `info <pkg>`: show a package's recorded metadata (or its registry coordinates if not installed) and whether it is up to date vs. the remote digest.
- `list`: list installed packages and their recorded digests by reading each `store/*/.sb-meta`.
- `outdated`: report installed packages whose remote digest has changed.

Common options: `--prefix PATH|--prefix=PATH` and `--arch ARCH|--arch=ARCH` (both `--opt value` and `--opt=value` forms accepted; options may appear before or after the package names). `--verbose` additionally mirrors the detailed log to stderr.

### Logging

Every invocation writes a detailed, structured (slog text) log to `<prefix>/sb.log` (the prefix is created if missing). The terminal shows simplified key-step output (the `> ...` lines, including install progress and an end-of-run summary with elapsed time) plus, during the download phase, a per-package byte-level progress bar (rendered by [mpb](https://github.com/vbauerster/mpb)); the full per-package resolve/download/extract/link events and phase timings go to the log file. Pass `--verbose` to also stream that log to stderr (it goes to stderr, so it does not clash with the progress bars on stdout).

This is a client-only concern: the CI/publishing model above is unchanged, because the comparison relies on the layer digest that `ghcr.io` already computes during `oras push`.

## How to Make Changes

### Add a new upstream tool from nixpkgs

1. Add an entry to [manifests/default.nix](file:///workspace/standalone-binaries/manifests/default.nix):
   - Omit `platforms` for an all-platform package, or set `platforms = [ "x86_64-linux" ]` / `[ "aarch64-darwin" ]` to restrict it.
   - For a package that exists everywhere but needs a different config per system, add a per-platform key, e.g. `aria2 = { "aarch64-darwin" = { version = "24.11"; }; };`.
2. Decide whether it should use `pkgsStatic` (`isStatic = true`, default) or regular `pkgs` (`isStatic = false`).
3. If the package has multiple outputs, pick the right one(s) via `output = [ "bin" ]` (or list several to merge them).
4. If the nixpkgs attribute name is awkward, use `alias` to export a better public name.
5. If the tool cannot be statically compiled, prefer the shared-sibling wrapper approach over `nix bundle`: ship it as a local package whose JS/runtime is reused from upstream and wrapped to invoke the co-located static `nodejs-slim26` sibling (see `pnpm`, `prettier`, `markdownlint-cli2`, `opencommit` under "local override", below). Use `bundle = true` (with `isStatic = false` and `platforms = [ "x86_64-linux" ]`) only as a true last resort for tools that have no reusable sibling runtime.

### Add a local override / patched build

1. Create a directory `packages/<pkg>/` with a `default.nix`, plus any resources (patches, wrapper scripts, vendored configs) the package needs alongside it.
2. Wire it into the appropriate set in `packages/local.nix` (`common`, `linux`, or `darwin`) via `callPackage ./<pkg> { }`. `local.nix` remains the explicit manifest of local packages (no auto-discovery).
3. Follow the standalone strategy: prefer static; otherwise patch + bundle; use `nix bundle` only when static is impossible.
4. Prefer minimal diffs: only patch what is necessary to improve portability, reduce dynamic deps, or fix runtime paths.

Example — Node.js tools (`packages/pnpm`, `packages/prettier`, `packages/markdownlint-cli2`, `packages/opencommit`): instead of `nix bundle`, each reuses the tool's JS distribution (`lib/node_modules/<pkg>`) and replaces the upstream bin wrapper(s) with a relative-path script that invokes the sibling static node (`$store/nodejs-slim26/bin/node`) explicitly, so the static node travels with the deployed tool instead of depending on a node on the host PATH after the standalone normalize pass. `pnpm`/`prettier` are additionally *built* against the static node by overriding the upstream interpreter (`pnpm` only unpacks JS; `prettier` fetches deps with pnpm), which exercises the static runtime end-to-end. `markdownlint-cli2`/`opencommit` are npm-based `buildNpmPackage` tools whose build needs `npm` (absent from `nodejs-slim`), so they are built with the regular node and only switch to the sibling static node at runtime. This supersedes the previous `bundle = true` entries for these tools in the manifest.

### Change normalization behavior

Edit [scripts/normalize.sh](file:///workspace/standalone-binaries/scripts/normalize.sh). Treat this script as a compatibility surface:
- Changing removals/rewrites can break tools in subtle ways.
- Prefer incremental changes and validate on a representative sample of packages.

## Design Documentation Rules

- This file is the design source of truth for the repository.
- Any change that affects architecture, build flow, package selection model, artifact format, or publishing model must update this document in the same change.
