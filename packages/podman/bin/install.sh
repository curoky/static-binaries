#!/usr/bin/env bash
set -xeuo pipefail

abspath=$(cd "$(dirname "$0")" && pwd)

mkdir -p /opt/podmanx/
rm -rf /opt/podmanx/bin /opt/podmanx/conf /opt/podmanx/libexec
cp -r $abspath/../bin $abspath/../conf $abspath/../libexec /opt/podmanx/
chmod -R +w /opt/podmanx/bin /opt/podmanx/conf /opt/podmanx/libexec

mkdir -p /etc/systemd/system/
rm -rf /etc/systemd/system/podmanxd.service
cp $abspath/../conf/podmanxd.service /etc/systemd/system/podmanxd.service

systemctl daemon-reload
systemctl enable podmanxd.service
systemctl start podmanxd.service
systemctl status podmanxd.service

chmod +777 /tmp/podmanxd.sock

# echo 'nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml'
