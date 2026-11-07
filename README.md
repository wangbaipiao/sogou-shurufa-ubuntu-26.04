> 由 **dsh + dpv4.1** 主刀，人工辅助实现 — *Main implementation by **DSH (DeepSeek Harness)** + **DP v4.1 (DeepSeek V4.1 Flash)**, with human assistance.*

# 搜狗输入法 NG × Ubuntu 26.04 / Fcitx 5 / Wayland

在 **Ubuntu 26.04** 上，用一套**完全免 root 的沙箱**验证「openKylin 搜狗输入法 NG（CPIS）能否适配 Fcitx 5 + Wayland」，并在真机上完成安装、设为默认输入法、记录已知缺陷。

本仓库是一份**可复现的验证工程**：包含沙箱构建脚本、四轮测试脚本、截图证据、日志摘录，以及完整的调查报告。

> ⚠️ 本项目**不分发**搜狗 / openKylin 的专有二进制。脚本只在运行时从镜像下载并校验上游 `.deb`。输入法本体是 2023 年的闭源产物，不受 Ubuntu、openKylin、搜狗任一方支持。

---

## 一、目的

官方搜狗拼音 Linux 版长期未更新， Ubuntu 26.04 已是 **Fcitx 5 + Wayland** 默认环境：

* 官方 `sogoupinyin 4.0.1.3057` 依赖 `fcitx (>= 1:4.2.8)`、`fcitx-frontend-gtk2/3`、`fcitx-module-x11`，属于 **Fcitx 4 插件 + X11** 架构；
* Fcitx 4 → 5 是架构级重构，插件 ABI 不兼容，旧版无法通过修改「转成 5」。

于是需要回答三个问题：

1. openKylin 社区已有的 **「搜狗 NG」Fcitx 5 组件**（CPIS，版本 10.0.9.0.6）能否在 Ubuntu 26.04 上装得上、被 Fcitx 5 加载？
2. 在 **Wayland 会话**下候选框能否正常显示、能否上屏？
3. 如果不能，代价多小的兜底方案是什么？

附带目标：**不污染真机**。整套验证在用户态命名空间里跑，不 `chroot`、不 `mount`、不需要 `sudo`。

---

## 二、适用系统与环境

### ✅ 已验证可用

| 项目 | 值 |
|---|---|
| 发行版 | **Ubuntu 26.04.1 LTS (resolute)** amd64 |
| 桌面 | **GNOME Shell 50.1** / `ubuntu:GNOME` 会话 |
| 显示协议 | **Wayland**（`XDG_SESSION_TYPE=wayland`），Mutter 18 + XWayland `:0` |
| 输入法框架 | **Fcitx 5 5.1.19** |
| IM 环境变量 | `GTK_IM_MODULE=fcitx`、`QT_IM_MODULE=fcitx`、`XMODIFIERS=@im=fcitx` |
| 关键前提 | 合成器 **不提供** `zwp_input_method_manager_v2`（Mutter 只提供 `zwp_text_input_manager_v3`） |
| 沙箱宿主 | Ubuntu 26.04，内核 7.0.0，bubblewrap 0.11.1，非特权 user namespace 可用 |

**结论：上述环境下，原生 Wayland GTK4 客户端实测可正常出候选框、空格上屏中文。**

### ⚠️ 部分可用 / 有条件

| 场景 | 说明 |
|---|---|
| **Ubuntu on Xorg** 会话 | 完整可用（沙箱 Xvfb + openbox 实测，有截图） |
| XWayland 客户端 | 可用（候选窗是 X11 窗口，天然适配） |
| 其它 Wayland 合成器（sway / wlroots 系） | ❌ **不保证**。sway 实现了 `zwp_input_method_manager_v2`，Fcitx 5 会切入原生 IM 协议，按键被抢走，CPIS 的 X11 面板拿不到输入 → 按键被吞、无候选窗 |
| GTK3 / Qt5 / Qt6 应用 | 理论上走同一套 IC API，未逐一实测 |
| Firefox / Chrome / Electron | 未实测 |
| 多屏 / 高缩放 | 中风险，候选窗按全局 X11 坐标摆放 |
| 其它发行版、其它 Ubuntu 版本、arm64 | 未测试。包内是 amd64 二进制且硬编码 `/usr/lib/x86_64-linux-gnu` |

### ❌ 不适用

* 官方旧版 `sogoupinyin*.deb`（Fcitx 4 插件，装不上也没意义）
* 无 XWayland 的纯 Wayland 会话 / `--no-x11` 的 Mutter
* 无 `bubblewrap` 或非特权 user namespace 被禁用的宿主机（沙箱跑不起来；真机安装不受影响）

---

## 三、实现过程

### 3.1 技术路线

不是「改造旧版搜狗」，而是采用 openKylin 已发布的 **搜狗 NG / CPIS** 组件：

```
Fcitx 5  ←→  libcpis-module-im-fcitx5.so  ←D-Bus→  cpis-engine-service (ISE)
                                          ←D-Bus→  cpis-panel-service (X11 候选窗)
```

* Fcitx 5 负责 Wayland 侧通信（`zwp_text_input_v3` / 客户端 im 模块）；
* CPIS 引擎负责拼音→候选；
* **候选窗由独立的 X11 面板进程绘制**（`com.cpis.panel.service.start.sh` 里硬编码 `GDK_BACKEND=x11`），不使用 Fcitx 5 的 UI。

集成方式选的是**方式 A**：社区项目 [`sunxfancy/sogou-ng-fcitx5-ubuntu`](https://github.com/sunxfancy/sogou-ng-fcitx5-ubuntu)（MIT）把 openKylin 的 7 个 deb 重打包成单个 Ubuntu 26.04 deb。

> 方式 B（照 AUR `fcitx5-sogou` 的 PKGBUILD 手工解包 7 个 deb + 建一个符号链接）实测可行，但**能力不超过方式 A**，且缺少 Fcitx 4 / Skia 模块清理与依赖声明，故未采用。

### 3.2 沙箱设计（核心）

```
bubblewrap 用户态命名空间（--unshare-user --uid 0）
  └─ 官方 ubuntu-base-26.04-base-amd64.tar.gz 根文件系统
       ├─ 独立 dbus-daemon --session
       ├─ 独立 XDG_RUNTIME_DIR
       ├─ GUI: headless sway(wlroots) + XWayland  /  Xvfb + openbox
       └─ 截图 grim / scrot / xwd，按键 wtype / xdotool
```

* 全程**无 sudo、无 chroot、无 mount**，与真实桌面完全隔离；
* apt 换清华 TUNA；openKylin deb 走阿里云；GitHub 走 `gh-proxy.com`；7 个 deb 与重打包 deb 均做 sha256 校验；
* 沙箱内补齐 `gsettings-desktop-schemas`（否则 Fcitx 5 的 wayland 插件因缺 `org.gnome.desktop.input-sources` 直接 abort）。

### 3.3 四轮验证（结论有反转，完整记录在 [REPORT.md](REPORT.md)）

| 轮次 | 环境 | 结论 |
|---|---|---|
| 第一轮 | Xvfb + openbox | X11 下**完整可用**：`nihao` → `1.你好 2.你号 …` → 空格上屏「你好」 |
| 第一轮 | headless sway + XWayland | 4 种组合全部**无候选窗**。当时误判为「搜狗 NG 不适配 Wayland」 |
| 第二轮 | 换成**真机同款 Mutter 50.1** | **结论反转**：sway 实现了 `input_method_manager_v2`，Fcitx 5 切入原生 IM 协议抢走按键；Mutter 没有该协议，走「客户端 im 模块 + X11 候选窗」老路 → CPIS 完全正常。第一轮是**沙箱合成器的锅** |
| 第三轮 | **真机** Ubuntu 26.04 + GNOME Wayland | 实际安装并验证：原生 Wayland GTK4 客户端打 `nihao` 上屏「你好」，CPIS 三进程稳定、面板零崩溃 |
| 第四轮 | 真机 | 把搜狗 NG 设为默认输入法（`DefaultIM`），并记录 fcitx5 退出时的 SIGSEGV |

**关键教训**：Wayland 输入法测试**必须用与目标机器相同的合成器**。sway 与 Mutter 的协议差异会导致完全相反的结论。

### 3.4 真机落地

```bash
# 1. 安装（apt --dry-run 先确认：只新增 1 个包，卸载 0）
sudo apt install ./sogou-ime-ng-fcitx5-ubuntu_*_amd64.deb

# 2. 重启 fcitx5 让新 addon 生效
fcitx5 -r            # 或注销重登

# 3. Fcitx 5 配置 → 取消「仅显示当前语言」→ 添加
#    「搜狗输入法NG麒麟桌面版（Powered by CPIS）」
# 4. Ctrl+Space 切换（默认组为 Default，DefaultIM 已指向搜狗 NG）
```

设为默认输入法时，正确顺序是 **`fcitx5-remote -e` → 改 `~/.config/fcitx5/profile` → `fcitx5 -d`**，否则退出时的状态落盘会覆盖改动。

---

## 四、复现

```bash
cd scripts
./build-rootfs.sh       # 建 Ubuntu 26.04 沙箱根文件系统（免 root，清华源）
./fetch-debs.sh         # 拉 7 个 openKylin deb（阿里云，sha256 校验）
./fetch-repack.sh       # 拉方式 A 重打包 deb（gh-proxy，SHA256SUMS 校验）
./install-sogou.sh      # 沙箱内安装 + 打印接入点
./run-x11.sh            # X11 会话测试（Xvfb + openbox）
./run-wayland.sh        # Wayland 会话测试（headless sway + XWayland）
./run-mutter.sh         # 复刻真机 Mutter 50.1 环境
./run-mutter-capture.sh # 同上，并抓取候选窗像素
```

沙箱默认位于 `/tmp/sandbox`（根文件系统 `/tmp/sandbox/rootfs`，截图 `/tmp/sandbox/shots`）。
`run-wayland.sh` 支持 `PANEL_BACKEND=x11|wayland` 切换 CPIS 面板的 GTK 后端。

**依赖**：`bubblewrap`、`curl`、`python3`、`tar`；脚本会在沙箱内自行 apt 安装 `fcitx5` / `sway` / `mutter` / `xvfb` / `xdotool` / `grim` 等。

---

## 五、已知问题

调查过程中在上游二进制里发现的、本项目无法修复的问题：

1. **候选窗是 X11 硬编码的**：`com.cpis.panel.service.start.sh` 写死 `GDK_BACKEND=x11` / `QT_QPA_PLATFORM=xcb`，不使用 Fcitx 5 的 UI。跨屏、缩放、光标跟随有风险。
2. **面板拿不到 `DISPLAY` 会 SIGSEGV 并被 D-Bus 无限重拉**（~90 ms 一次）。真机上 `systemd --user` 环境带 `DISPLAY` 时不会触发，但仍属隐患。
3. **按键模拟器 `.so` 缺失**：`frontend.ini` 声明 wayland 后端用 `libcpis-module-keystroke-simulator-xinput.so`，包里只有 `-linux.so` / `-xtst.so`，日志反复报 `open ks module failed`。会导致偶发的按键状态同步错误。
4. **回车会把拼音原文整串上屏**：实测 `dangfengbei` + 空格 → `挡风被`，但 + 回车 → `dangfengbei`。这是「拼音串直通」行为，不是候选焦点跑偏。误触回车/小键盘 Enter 时会看到「空格下去不是第一个选项」的假象。
5. **fcitx5 退出时 SIGSEGV**：CPIS 插件被使用过后，卸载阶段会段错误（`/var/crash/_usr_bin_fcitx5.*.crash`）。不影响打字和下次登录，但会弹 apport 提示。
6. **日志无上限增长**：真机上 `~/.com.cpis.panel.log` / `~/.com.cpis.engine.log` 可涨到 100 MB+，且 ISE_NODE 子进程长期不回收。建议定期清理并重启输入法。
7. **许可证校验器**：`license.signed.xml` + `pubkey.pem`，含时钟判断，长期可用性无保证。
8. 上游 README 自述：「只验证包结构和链接，不保证所有 Wayland 应用兼容」，并列出「候选词数字键错位」。

---

## 六、回滚

```bash
fcitx5-remote -s rime                              # 立刻切回原输入法
sudo apt remove sogou-ime-ng-fcitx5-ubuntu        # 彻底卸载
cp ~/sogou-ng-rollback/profile.before-default ~/.config/fcitx5/profile
fcitx5 -r                                          # 还原输入法组
```

---

## 七、目录结构

```
README.md                 本文档
REPORT.md                 四轮调查的完整原始记录（含被推翻的中间结论）
screenshots/              实测截图（X11 可用 / sway 失败 / 对照组 / Mutter 候选窗）
logs/                     关键日志摘录
scripts/
  build-rootfs.sh         免 root 构建 Ubuntu 26.04 沙箱根文件系统
  fetch-debs.sh           下载并校验 7 个 openKylin deb
  fetch-repack.sh         下载并校验方式 A 重打包 deb
  install-sogou.sh        沙箱内安装并打印 fcitx5 接入点
  runner-bwrap.sh         bubblewrap 沙箱入口
  run-x11.sh              Xvfb + openbox 测试
  run-wayland.sh          sway + XWayland 测试
  run-mutter.sh           Mutter 50.1 复刻测试
  run-mutter-capture.sh   同上 + 候选窗抓图
  test-entry*.py          GTK3/GTK4 测试输入框
  ic-client.py            直接驱动 fcitx5 portal 输入上下文的测试桩
  sway.conf               无头 sway 配置
```

---

## 八、致谢与免责

* 上游组件来自 **openKylin** 的搜狗 NG / CPIS，重打包 deb 来自 [`sunxfancy/sogou-ng-fcitx5-ubuntu`](https://github.com/sunxfancy/sogou-ng-fcitx5-ubuntu)（MIT），AUR 参考 [`fcitx5-sogou`](https://aur.archlinux.org/packages/fcitx5-sogou)。
* 镜像：清华 TUNA、阿里云 openKylin、`gh-proxy.com`。
* 本项目仅为**验证记录与测试脚本**，不含专有二进制，不提供任何保证，与 Ubuntu / openKylin / 搜狗官方无关。
* 使用前请自行评估闭源二进制与第三方重打包包的安全风险，并保留回滚能力。
