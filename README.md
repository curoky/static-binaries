# Prebuild static executables

![build thrift](https://github.com/curoky/prebuild-binary/workflows/build%20thrift/badge.svg)
![build fbthrift](https://github.com/curoky/prebuild-binary/workflows/build%20fbthrift/badge.svg)
![build llvm](https://github.com/curoky/prebuild-binary/workflows/build%20llvm/badge.svg)
![build protoc](https://github.com/curoky/prebuild-binary/workflows/build%20protoc/badge.svg)
![build xz](https://github.com/curoky/prebuild-binary/workflows/build%20xz/badge.svg)

## Download

- [thrift](https://bintray.com/curoky/prebuild-binary/thrift#files)
- [fbthrift](https://bintray.com/curoky/prebuild-binary/fbthrift#files)
- [llvm](https://bintray.com/curoky/prebuild-binary/llvm#files)
  - clang-format
  - clang-query
  - clang-tidy
- [protoc](https://bintray.com/curoky/prebuild-binary/protoc#files)
- [xz](https://bintray.com/curoky/prebuild-binary/xz#files)

## develop

1. tap this repo

   ```bash
   ln -s prebuild-binary "$(brew --prefix)/Homebrew/Library/Taps/local/homebrew-prebuild-binary"
   ```

2. build static binary from source

   ```bash
   brew install <name>@<version>
   ```

## Other

Inspired by [clang-tools-static-binaries](https://github.com/muttleyxd/clang-tools-static-binaries) and [Homebrew](https://brew.sh)
