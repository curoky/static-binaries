#!/usr/bin/env bash
# Copyright (c) 2024-2025 curoky(cccuroky@gmail.com).
#
# This file is part of prebuilt-tools.
# See https://github.com/curoky/prebuilt-tools for further info.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -xeuo pipefail

name=$1
prefix="$2"

skip_list=(
  nsight-systems

  iina
  snipaste
  keka
  obs-studio
)

if [[ " ${skip_list[@]} " =~ " ${name} " ]]; then
  exit 0
fi

# remove path which contain nix
for f in $(find $prefix -type f); do
  if file --brief "$f" | grep -q 'text'; then
    sed -e 's|#\!\s*/nix/store/[a-z0-9\._-]*/bin/|#\! /usr/bin/env |g' -i"" "$f" || true
    sed -e 's|/nix/store/[a-z0-9\._-]*/bin/||g' -i"" "$f" || true
  fi
done

# strip binaries for reducing size
for f in $(find $prefix -type f); do
  if file --brief "$f" | grep -q 'ELF'; then
    strip --strip-unneeded "$f"
  fi
done

# clean up unnecessary files
find $prefix -name "*.a" -delete
find $prefix -name "*.pyc" -delete
find $prefix -type d -name man -exec rm -rf {} +
find $prefix -type d -name fish -exec rm -rf {} +
find $prefix -type d -name bash-completion -exec rm -rf {} +
find $prefix -type d -name nix-support -exec rm -rf {} +

# remove invalid link
find $prefix -type l -exec test ! -e {} \; -print | while read -r file; do
  rm -rf "$file"
done

# remove outside links
find $prefix -type l | while read -r link; do
  target=$(readlink -f "$link")
  if [[ $target != "$prefix"* ]]; then
    rm -v "$link"
  fi
done

# rename wrapped files
find $prefix -type f -name ".*-wrapped" | while read -r file; do
  dir=$(dirname "$file")
  new_name=$(basename "$file" | sed -e 's/-wrapped//g' -e 's/^.//')
  mv "$file" "$dir/$new_name"
done
