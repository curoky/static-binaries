# static binaries

[![build fbthriftc](https://github.com/curoky/static-binaries/actions/workflows/build-fbthriftc.yaml/badge.svg)](https://github.com/curoky/static-binaries/actions/workflows/build-fbthriftc.yaml)
[![build llvm tools](https://github.com/curoky/static-binaries/actions/workflows/build-llvm-tools.yaml/badge.svg)](https://github.com/curoky/static-binaries/actions/workflows/build-llvm-tools.yaml)
[![build protoc](https://github.com/curoky/static-binaries/actions/workflows/build-protoc.yaml/badge.svg)](https://github.com/curoky/static-binaries/actions/workflows/build-protoc.yaml)
[![build thriftc](https://github.com/curoky/static-binaries/actions/workflows/build-thriftc.yaml/badge.svg)](https://github.com/curoky/static-binaries/actions/workflows/build-thriftc.yaml)
[![build tmux](https://github.com/curoky/static-binaries/actions/workflows/build-tmux.yaml/badge.svg)](https://github.com/curoky/static-binaries/actions/workflows/build-tmux.yaml)
[![build xz](https://github.com/curoky/static-binaries/actions/workflows/build-xz.yaml/badge.svg)](https://github.com/curoky/static-binaries/actions/workflows/build-xz.yaml)

Various versions of \*nix tools are built as statically linked binaries, **no** system library dependencies including **glibc**.

## Current List of Tools

- thrift compiler (0.8.0~0.15.0)
- fbthrift compiler (2020.12.14/2020.12.14)
- protobuf compiler (2020.12.14/2020.12.14)
- llvm tools (3.9.1 ~ 12.0.1)
  - clang-format
  - clang-query
  - clang-tidy
- tmux (2.9a/3.2a)
- xz (5.0.8/5.2.5)

## Download from release

In most cases, you can download the pre-compiled version directly from [release](https://github.com/curoky/static-binaries/releases).

Example for downloading clang-format.

```bash
➜ curl -sSL -o clang-format https://github.com/curoky/static-binaries/releases/download/v1.0.0/clang-format-10.0.1

➜ chmod +x ./clang-format

➜ ./clang-format --version
clang-format version 10.0.1

➜ ldd ./clang-format
        not a dynamic executable
```

## Build from source

In other cases, you can manually build.

1. install [homebrew](https://brew.sh/)

2. tap this repo

```bash
ln -s $PWD/static-binaries $(brew --prefix)/Homebrew/Library/Taps/local/homebrew-static-binaries
```

3. install the specified version of binary

```bash
export HOMEBREW_PROTOC_VERSION="3.17.3"
brew install protoc
cp $(brew --prefix protoc)/bin/protoc .
```
