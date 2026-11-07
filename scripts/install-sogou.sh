#!/bin/bash
# 在沙箱内安装方式 A 的重打包 deb，并打印安装结果
set -euo pipefail
BASE=${1:-/tmp/sandbox}
cd "$BASE"
./runner-bwrap.sh bash -c '
  export PATH=/usr/local/sbin:$PATH
  DEBIAN_FRONTEND=noninteractive
  cp /mnt/rel/*.deb /tmp/
  apt-get install -y /tmp/sogou-ime-ng-fcitx5-ubuntu_*.deb 2>&1 | tail -20
  echo "----- 安装后的 fcitx5 接入点 -----"
  ls -l /usr/lib/x86_64-linux-gnu/fcitx5/ | grep -i cpis
  ls /usr/share/fcitx5/addon/ /usr/share/fcitx5/inputmethod/ | grep -i sogou
  ls -l /usr/share/dbus-1/services/ | grep -i cpis
  dpkg -s sogou-ime-ng-fcitx5-ubuntu | grep -E "^(Package|Version|Depends)"
'
