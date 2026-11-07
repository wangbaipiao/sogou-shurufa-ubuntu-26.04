#!/bin/bash
# bubblewrap 沙箱入口。
# 沙箱根目录可用 SOGOU_SANDBOX 覆盖，默认 /tmp/sandbox。
set -euo pipefail
BASE=${SOGOU_SANDBOX:-/tmp/sandbox}
ROOT="$BASE/rootfs"
for d in "$ROOT" "$BASE/debs" "$BASE/rel" "$BASE/shots"; do
  [ -e "$d" ] || { echo "缺少 $d，请先运行 build-rootfs.sh / fetch-*.sh" >&2; exit 1; }
done
exec bwrap \
  --bind "$ROOT" / \
  --dev /dev --proc /proc --bind /sys /sys \
  --tmpfs /tmp --tmpfs /run \
  --bind /etc/resolv.conf /etc/resolv.conf \
  --ro-bind "$BASE/debs" /mnt/debs \
  --ro-bind "$BASE/rel" /mnt/rel \
  --ro-bind "$BASE" /mnt/sb \
  --bind "$BASE/shots" /mnt/shots \
  --unshare-user --uid 0 --gid 0 \
  --unshare-pid --unshare-uts --unshare-ipc --unshare-cgroup \
  --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  --setenv HOME /root --setenv LANG C.UTF-8 --setenv DEBIAN_FRONTEND noninteractive \
  --setenv SOGOU_SANDBOX "$BASE" \
  --chdir /root --die-with-parent \
  "$@"
