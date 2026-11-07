#!/bin/bash
# 从零重建 Ubuntu 26.04 沙箱根文件系统（全程免 root，只用用户态 user namespace）
# 用法: ./build-rootfs.sh [/tmp/sandbox]
set -euo pipefail
BASE=${1:-/tmp/sandbox}
ROOT="$BASE/rootfs"
MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/26.04/release

mkdir -p "$BASE"
cd "$BASE"

echo "==> 1. 下载官方 ubuntu-base 26.04 amd64 根文件系统（清华镜像）"
[ -f ubuntu-base-26.04.tar.gz ] || curl -fSL -o ubuntu-base-26.04.tar.gz "$MIRROR/ubuntu-base-26.04-base-amd64.tar.gz"
curl -fsS "$MIRROR/SHA256SUMS" | grep 'ubuntu-base-26.04-base-amd64.tar.gz' | sha256sum -c -

echo "==> 2. 解包（不需要 root，tar 以当前用户身份落盘）"
mkdir -p "$ROOT"
tar xzf ubuntu-base-26.04.tar.gz -C "$ROOT" --exclude='./dev/*'

echo "==> 3. 换国内 apt 源 + 关掉 apt 的 _apt 降权（单 uid 的 user namespace 里没第二个 uid）"
sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirrors.tuna.tsinghua.edu.cn/ubuntu/|; s|http://security.ubuntu.com/ubuntu/|http://mirrors.tuna.tsinghua.edu.cn/ubuntu/|' \
  "$ROOT"/etc/apt/sources.list.d/*.sources
printf 'APT::Sandbox::User "root";\n' > "$ROOT"/etc/apt/apt.conf.d/99-sandbox-user.conf

echo "==> 4. 装 dpkg-statoverride/systemctl 等空壳脚本（沙箱里无法 chown 到未映射 uid）"
mkdir -p "$ROOT"/usr/local/sbin
for c in dpkg-statoverride systemctl deb-systemd-helper deb-systemd-invoke service invoke-rc.d; do
  printf '#!/bin/sh\nexit 0\n' > "$ROOT"/usr/local/sbin/$c
  chmod +x "$ROOT"/usr/local/sbin/$c
done

echo "==> 5. 测试环境所需的包（fcitx5 5.1.19 / GTK3 / GTK4 / sway / 测试工具）"
./runner-bwrap.sh bash -c '
  export PATH=/usr/local/sbin:$PATH
  DEBIAN_FRONTEND=noninteractive apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    fcitx5 fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-modules fcitx5-data \
    fcitx5-chinese-addons dbus fonts-noto-cjk python3-gi gir1.2-gtk-4.0 gir1.2-gtk-3.0 \
    gsettings-desktop-schemas libgl1-mesa-dri \
    sway grim wtype xwayland xauth \
    xvfb openbox xdotool scrot
  dpkg --configure -a || true
'

echo "==> 完成: $ROOT ($(du -sh "$ROOT" | cut -f1))"
echo "下一步: ./fetch-debs.sh && ./install-sogou.sh && ./run-x11.sh | ./run-wayland.sh"
