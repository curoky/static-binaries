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

PACKAGE_NAME=${1:-"curl"}
ARCH_NAME=${2:-"linux-x86_64"}

docker buildx build . \
  --file docker/Dockerfile \
  --network=host \
  --build-arg PACKAGE_NAME=$PACKAGE_NAME \
  --build-arg ARCH_NAME=$ARCH_NAME \
  --tag curoky/static-binaries:main

id=$(docker create curoky/static-binaries:main)
docker cp $id:/tmp/${PACKAGE_NAME}.${ARCH_NAME}.tar.gz - >${PACKAGE_NAME}.${ARCH_NAME}.tar.gz.tar
docker rm -v $id
tar -xvf ${PACKAGE_NAME}.${ARCH_NAME}.tar.gz.tar
rm -rf ${PACKAGE_NAME}.${ARCH_NAME}.tar.gz.tar
