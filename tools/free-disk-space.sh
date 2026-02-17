#!/usr/bin/env bash
# Copyright (c) 2018-2024 curoky(cccuroky@gmail.com).
#
# This file is part of minimal-example.
# See https://github.com/curoky/minimal-example for further info.
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
set -x

# https://raw.githubusercontent.com/apache/flink/master/tools/azure-pipelines/free_disk_space.sh
# https://github.com/marketplace/actions/free-disk-space-ubuntu

df -h

sudo apt-get update -y
sudo apt-get install -y ncdu
# dump original disk info, too slow
# sudo ncdu -o info.txt /

# gcc
for i in {4..14}; do
  sudo apt-get purge -y {gcc,g++,cpp}-$i
done
sudo apt-get purge -y llvm* libllvm*
df -h

# dpkg-query -W -f='${Installed-Size;8}  ${Package}\n' | sort -n

# database
sudo apt-get purge -y mysql* postgresql* mongodb*
df -h

# other apps
sudo apt-get purge -y openjdk* php* powershell mono* nginx* r-* snapd temurin* podman \
  aspnetcore* ant* apache2 azure* dotnet* firefox gh google* linux-azure* microsoft* \
  libicu* heroku fonts* kubectl mercurial mssql* ruby* xdg* x11*
df -h

sudo apt-get autoremove
df -h

rustup self uninstall -y
df -h

docker system prune -a -f
df -h

sudo rm -rf \
  /opt/hostedtoolcache \
  /opt/pipx \
  /opt/runner-cache \
  /opt/actionarchivecache \
  /usr/local/lib/android \
  /usr/local/lib/node_modules \
  /home/linuxbrew \
  /usr/local/.ghcup \
  /usr/local/share/chromium \
  /usr/local/share/powershell \
  /usr/local/share/vcpkg \
  /usr/local/julia* \
  /usr/local/aws* \
  /usr/share/dotnet \
  /usr/share/swift \
  /usr/share/miniconda \
  /usr/share/az_* \
  /usr/share/gradle-* \
  /usr/share/sbt \
  /usr/share/kotlinc \
  /usr/lib/jvm \
  /usr/lib/google-cloud-sdk \
  /usr/lib/firefox \
  /etc/skel

df -h

free

# sudo ncdu -o info.txt /
