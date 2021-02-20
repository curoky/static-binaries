# LLVM-tools prebuild static executables

![build llvm tools](https://github.com/curoky/llvm-tool-binary/workflows/build%20llvm%20tools/badge.svg)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![release](https://img.shields.io/github/v/release/curoky/llvm-tool-binary)](https://github.com/curoky/llvm-tool-binary/releases)

## Why we need this

Inspired by [clang-tools-static-binaries](https://github.com/muttleyxd/clang-tools-static-binaries) and [Homebrew](https://brew.sh)

From [clang-tools-static-binaries](https://github.com/muttleyxd/clang-tools-static-binaries).

> I use to contribute to different repositories and they often use different versions of clang-format.
>
> I could either compile clang-format for each one I want to have or I could try messing up with my package system (I use Arch Linux btw) and try installing all of them on my system. This can very quickly get out of hand, hence I created this repository.
>
> These binaries aim to:
>
> - be as small as possible
> - not require any additional dependencies apart from OS itself

For more convenient maintenance, I migrate the compilation process to homebrew.

## Download

1. download binary from [Releases](https://github.com/curoky/llvm-tool-binary/releases)

2. install with homebrew

```bash
brew tap curoky/llvm-tool-binary https://github.com/curoky/llvm-tool-binary
brew install llvm-tools@3
```
