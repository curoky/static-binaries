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

prefix="$1"

find "$prefix" -type f -print0 | while IFS= read -r -d '' f; do

  # 获取文件类型信息，减少重复调用 file 命令
  FTYPE=$(file --brief "$f")

  # --- A. 路径脱敏 (针对文本文件) ---
  if echo "$FTYPE" | grep -q 'text'; then
    sed -e 's|#\!\s*/nix/store/[a-z0-9\._-]*/bin/|#\! /usr/bin/env |g' \
      -e 's|/nix/store/[a-z0-9\._-]*/bin/||g' -i "$f"
    sed -E 's|/nix/store/[a-z0-9]{32}-[^[:space:]:/()<>]*||g' -i "$f"

  # --- B. 符号剥离 (针对 ELF 二进制) ---
  elif echo "$FTYPE" | grep -q 'ELF'; then
    strip --strip-unneeded "$f" || true
    nuke-refs "$f"
  fi

  # --- C. 还原包裹文件 (Unwrap) ---
  # 放在这里处理是因为它们也是 type f
  if [[ $(basename "$f") == .*-wrapped ]]; then
    dir=$(dirname "$f")
    new_name=$(basename "$f" | sed -e 's/-wrapped//g' -e 's/^.//')
    mv "$f" "$dir/$new_name"
  fi

  # --- D. 特定后缀清理 ---
  if [[ $f == *.a ]] || [[ $f == *.pyc ]]; then
    rm -f "$f"
  fi
done

# 3. 目录与链接清理 (这些操作涉及目录结构或特殊类型，单独处理)
echo "Cleaning up directories and links..."

# 批量删除不需要的目录
# find "$prefix" -type d \( -name "man" -o -name "fish" -o -name "bash-completion" -o -name "nix-support" \) -exec rm -rf {} +
rm -rf $prefix/nix-support

# 处理链接：删除无效链接及指向外部的链接
find "$prefix" -type l -print0 | while IFS= read -r -d '' link; do
  target=$(readlink -f "$link")
  if [[ ! -e $link ]] || [[ $target != "$prefix"* ]]; then
    rm -f "$link"
  fi
done

# # remove path which contain nix
# for f in $(find $prefix -type f); do
#   if file --brief "$f" | grep -q 'text'; then
#     sed -e 's|#\!\s*/nix/store/[a-z0-9\._-]*/bin/|#\! /usr/bin/env |g' -i"" "$f" || true
#     sed -e 's|/nix/store/[a-z0-9\._-]*/bin/||g' -i"" "$f" || true
#   fi
# done

# # strip binaries for reducing size
# for f in $(find $prefix -type f); do
#   if file --brief "$f" | grep -q 'ELF'; then
#     strip --strip-unneeded "$f"
#   fi
# done

# # clean up unnecessary files
# find $prefix -name "*.a" -delete
# find $prefix -name "*.pyc" -delete
# find $prefix -type d -name man -exec rm -rf {} +
# find $prefix -type d -name fish -exec rm -rf {} +
# find $prefix -type d -name bash-completion -exec rm -rf {} +
# find $prefix -type d -name nix-support -exec rm -rf {} +

# # remove invalid link
# find $prefix -type l -exec test ! -e {} \; -print | while read -r file; do
#   rm -rf "$file"
# done

# # remove outside links
# find $prefix -type l | while read -r link; do
#   target=$(readlink -f "$link")
#   if [[ $target != "$prefix"* ]]; then
#     rm -v "$link"
#   fi
# done

# # rename wrapped files
# find $prefix -type f -name ".*-wrapped" | while read -r file; do
#   dir=$(dirname "$file")
#   new_name=$(basename "$file" | sed -e 's/-wrapped//g' -e 's/^.//')
#   mv "$file" "$dir/$new_name"
# done
