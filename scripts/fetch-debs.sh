#!/bin/bash
# 下载 openKylin「搜狗 NG / CPIS」7 个上游 deb（阿里云镜像，国内直连）
# 校验值取自 AUR fcitx5-sogou 的 PKGBUILD
set -euo pipefail
BASE=${1:-/tmp/sandbox}
D="$BASE/debs"; mkdir -p "$D"; cd "$D"
M=https://mirrors.aliyun.com/openkylin/pool/pty
while read -r url sum; do
  f=${url##*/}
  [ -f "$f" ] || curl -fSL -o "$f" "$url"
  echo "$sum  $f" | sha256sum -c -
done <<EOF
$M/c/cpis/cpis-base_10.0.9.0.6-202311280935_amd64.deb 615482541d573bd5b07d119f9b5f93d741a7c5a4d89fc6cc3bd93c1b76205af5
$M/s/sogou-ime-ng-data/sogou-ime-ng-cpis-dict-keyboard-chs-pcpy_10.0.1-48.1_all.deb ee40d758cd557d238cfc398af0fdc7480e7df6ea30566ff7fbdeca4add35822f
$M/s/sogou-ime-ng-data/sogou-ime-ng-cpis-dict-keyboard-chs-pcwb_10.0.1-48.1_all.deb 5d02a30b88fc977dba6a04eea3f73b949d7becbded816581f6c271dad2f8ab32
$M/s/sogou-ime-ng-data/sogou-ime-ng-cpis-dict-keyboard-multilingual-pcen_10.0.1-48.1_all.deb cebb053ac612ce64e97b69557f1c9911207e198cc0d8c7e57d8e0a20b722d45c
$M/s/sogou-ime-ng-data/sogou-ime-ng-cpis-user-default-profile_10.0.1-48.1_all.deb fb5268eae8870a08988e81f0839d3c2f0ad7898b6871bb4e5cfe739bfc8a0d54
$M/s/sogou-ime-ng/sogou-ime-ng-fcitx5-kylin-desktop_10.0.9.0.6-20231128000607_amd64.deb 99fd9f7b512cc367b44f13029b282fcb2387ddb1e26f7caa1ffa1cfe5f0b5532
$M/s/sogou-ime-ng/sogou-ime-ng_10.0.9.0.6-20231128000607_amd64.deb 9fd28578f1980ed715bcda5e7e0ae80239638e3af82f57c3d156f8d5946e6c82
EOF

# 方式 A 的重打包 deb 由 fetch-repack.sh 单独下载
