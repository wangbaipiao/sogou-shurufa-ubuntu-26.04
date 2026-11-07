#!/bin/bash
# 下载方式 A（sunxfancy/sogou-ng-fcitx5-ubuntu）预编译的 Ubuntu 26.04 重打包 deb
# 走 gh-proxy 镜像；校验其官方 SHA256SUMS
set -euo pipefail
BASE=${1:-/tmp/sandbox}
mkdir -p "$BASE/rel"; cd "$BASE/rel"
B=https://gh-proxy.com/https://github.com/sunxfancy/sogou-ng-fcitx5-ubuntu/releases/download/v10.0.9.0.6-ubuntu2
F='sogou-ime-ng-fcitx5-ubuntu_10.0.9.0.6-20231128000607+ubuntu26.04.1_amd64.deb'
[ -f "$F" ] || curl -fSL -o "$F" "$B/$F"
[ -f SHA256SUMS ] || curl -fsSL -o SHA256SUMS "$B/SHA256SUMS"
sha256sum -c SHA256SUMS
ls -lh
