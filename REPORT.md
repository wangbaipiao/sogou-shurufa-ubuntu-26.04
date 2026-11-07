> 由 **dsh + dpv4.1** 主刀，人工辅助实现 — *Main implementation by **DSH (DeepSeek Harness)** + **DP v4.1 (DeepSeek V4.1 Flash)**, with human assistance.*

# 搜狗输入法 NG + Fcitx 5 在 Ubuntu 26.04 上的沙箱实测报告

测试日期：2026-10-28　目标环境：Ubuntu 26.04 (resolute) amd64 + Fcitx 5
测试方式：**全程免 root 的 user-namespace 沙箱**，与你的真实桌面完全隔离。

---

## 0. 一句话结论

这个思路**技术上成立**：openKylin 的搜狗 NG（CPIS）在 Ubuntu 26.04 上**装得上、Fcitx 5 加载得上、在 X11 会话里实测可正常打字**（有截图）。
但**“Wayland 下候选框”这一关，在我的沙箱里没能通过**，而且失败点正好落在搜狗 NG 的架构命门上（候选窗由一个硬编码 `GDK_BACKEND=x11` 的独立面板进程绘制）。沙箱本身也无法渲染任何 IME 的候选窗，所以 Wayland 这一项只能算**“未证实 + 高风险”**，不是“已证伪”。

换句话说：**方式 A 可以试，建议先在 “Ubuntu on Xorg” 会话下用；真正在 GNOME Wayland 下能不能出候选框，只能在你的真机上验一次。**

---

## 1. 前提核对：你说的话哪些对、哪些不对

| 你的说法 | 实测结果 | 证据 |
|---|---|---|
| 官方旧版搜狗绑 Fcitx 4，不能简单改成 Fcitx 5 | ✅ 对 | openKylin 仓库里 `sogoupinyin 4.0.1.3057` 的依赖是 `fcitx (>= 1:4.2.8)`、`fcitx-frontend-gtk2/gtk3`、`fcitx-module-x11`；Ubuntu 26.04 已无 Fcitx 4 核心 |
| 强行装旧 deb 会有依赖冲突、装不上 | ❌ **不成立** | 旧的 `sogoupinyin` 才依赖 Fcitx 4；而搜狗 NG 的 7 个 deb **几乎不声明依赖**（`sogou-ime-ng` 只 `Depends: cpis-base`，`cpis-base` 连 Depends 都没有）。方式 A 的单个 deb 在干净 26.04 上 **apt 一次装完，零冲突** |
| 可行路径是 openKylin 的“搜狗 NG”（10.0.9.0.6） | ✅ 对 | 上游 7 个 deb 全部从阿里云 openKylin 镜像拉到，sha256 与 AUR `fcitx5-sogou` 的 PKGBUILD 完全一致 |
| 方式 A 是“非官方 Ubuntu 24/26 兼容助手” | ⚠️ 名字不对，东西真的有 | 实际项目是 GitHub `sunxfancy/sogou-ng-fcitx5-ubuntu`（MIT，把 7 个 deb 重打包成 1 个 Ubuntu 26.04 deb，有预编译 Release）。**它不是“助手/一键脚本”**，装完还得手动在 Fcitx 5 配置里添加输入法 |
| 方式 B 手动集成 AUR PKGBUILD | ⚠️ 可行但没必要 | AUR 的 `fcitx5-sogou` 干的事就是“解这 7 个 deb + 建一个符号链接”，我已经手动复现（见下），**没有任何超出方式 A 的能力**，反而少了 Fcitx 4/Skia 清理和依赖声明 |

---

## 2. 沙箱怎么搭的（不碰你的系统）

* **隔离层**：`bubblewrap`（`bwrap --unshare-user --uid 0`）+ 官方 `ubuntu-base-26.04-base-amd64.tar.gz` 根文件系统（清华镜像，sha256 校验）。
* 用的是你机器上已有的内核，但**没有 chroot、没有 mount、没有 sudo**（本机 sudo 需要密码，全程未使用）。
* 沙箱内：独立根文件系统、独立 `dbus-daemon --session`、独立 `XDG_RUNTIME_DIR`，GUI 用 **headless sway（wlroots 0.19）+ XWayland** 或 **Xvfb + openbox** 跑，截图用 `grim`/`scrot`，按键注入用 `wtype`/`xdotool`。
* 沙箱内的版本：`fcitx5 5.1.19-1`、`gtk3 3.24.52`、`gtk4 4.22.4`、`qt5 5.15.18`、`glibc 2.43`、`sway 1.11`。
* 外网全部走镜像：Ubuntu → 清华 TUNA；openKylin deb → 阿里云；GitHub（项目源码与 Release deb）→ `gh-proxy.com`。

脚本都在 `scripts/`，`REPORT.md` 同级有 `screenshots/` 和 `logs/`。

---

## 3. 实测结果

### 3.1 安装：干净 26.04 上零冲突 ✅

```
Setting up sogou-ime-ng-fcitx5-ubuntu (10.0.9.0.6-20231128000607+ubuntu26.04.1) ...
```
依赖 `fcitx5 (>=5.1)`、`fcitx5-frontend-all`、`fcitx5-config-qt`、`libqt5*core/gui/widgets`、`libgtk-3-0t64`、`libopenal1`、`libcurl4t64`、`libxtst6` 全部满足（顺带装了 Qt5/Qt6、qt5-wayland、fcitx5-qt 前端）。
同时落地的接入点：

```
/usr/lib/x86_64-linux-gnu/fcitx5/libcpis-module-im-sogou-ime-ng-fcitx5-kylin-desktop.so -> ../cpis-module-im-fcitx5.so
/usr/share/fcitx5/addon/sogou-ime-ng-fcitx5-kylin-desktop-addon.conf
/usr/share/fcitx5/inputmethod/sogou-ime-ng-fcitx5-kylin-desktop.conf
/usr/share/dbus-1/services/com.cpis.engine.service, com.cpis.panel.service
```

### 3.2 Fcitx 5 能否加载 2023 年的老插件：能 ✅

```
I addonmanager.cpp:204] Loaded addon sogou-ime-ng-fcitx5-kylin-desktop-addon
```
`libcpis-module-im-fcitx5.so` 链接的是 `libFcitx5Core.so.7 / Config.so.6 / Utils.so.2`，与 26.04 的 Fcitx 5.1.19 同名同 ABI；addon 声明 `Version=5.0.11`，Fcitx 5 只拒绝“要求更高版本”的插件，所以能加载。

### 3.3 X11 会话：完整可用 ✅（有图为证）

Xvfb 1280x800 + openbox，GTK4 测试窗口，输入 `nihao`：

* 预编辑 `ni'hao`
* 候选：`1.你好 2.你号 3.拟好 4.倪好 5.倪浩 6.泥蒿`
* 右下角出现搜狗状态条（中/英、皮肤按钮）
* 按空格 → 输入框里得到 **你好**

截图：`screenshots/01-x11-preedit-candidates.png`、`screenshots/02-x11-committed.png`

这说明：**CPIS 引擎、词库、皮肤、Fcitx 5 桥接、D-Bus 服务链，在 Ubuntu 26.04 上是能跑通的**——不是“二进制不兼容”。

### 3.4 Wayland 会话：四种组合都没能出候选框 ❌（但沙箱也有责任）

在 headless sway + XWayland 下我穷举了 4 种组合（客户端 Wayland/X11 × 面板 GTK 后端 x11/wayland），并把 Fcitx 5 也分别用「Wayland 原生 IM 协议」和「关掉 wayland 插件、纯 X11」跑过：

| 客户端 | CPIS 面板 | 结果 |
|---|---|---|
| Wayland (GTK4) | X11 (上游默认) | 按键被吞，无预编辑、无候选窗、无上屏 |
| Wayland (GTK4) | Wayland | 同上 |
| X11 (XWayland) | X11 | 只冒出 205x30 的状态条，仍无候选窗 |
| X11 (XWayland) | X11 + Fcitx5 关 wayland | 同上 |

面板日志显示它只创建了 `status / softkeyboard / t9keyboard` 三个窗口，**始终没有 X11 会话里那个 `composition`（候选/预编辑）窗口**：

```
wndname= status  position= 866, 672      # 只有状态条
# 纯 X11 会话里同一条日志是：
Move  wndname= composition ...  (341, 374, 575, 76)   # 候选窗
```

按键确实进了引擎（`do keydown, key: [73:I], return code: [1]`、`ui TouchUp do UpdatePage end` → 候选页已经算出来了），**只是没画出来**。

**必须诚实说明的对照组**：在同一个 sway 沙箱里，Fcitx 5 自带拼音也只能把预编辑 `ni hao` 打进输入框，**同样没有候选窗**（见 `screenshots/04-wayland-pinyin-control-no-candidate-window.png`）。所以“Wayland 下没有候选框”这件事，**部分是沙箱/合成器的限制**（sway 的 input-method-v2 支持不完整，Fcitx 5 的 wayland 候选窗画不出来），不能全部算在搜狗头上。
但两者的差别是实质性的：

* Fcitx 5 原生拼音：预编辑由**客户端**绘制 → 至少你能看见自己在打什么；
* 搜狗 NG：预编辑和候选**都在它自己的 X11 面板里画** → 面板一挂，你就是“按键被吞、屏幕无反应”。

---

## 4. 代码/包层面查到的真问题（和 Wayland 直接相关）

1. **候选窗是 X11 硬编码的**。`/usr/bin/com.cpis.panel.service.start.sh` 里写死：
   ```sh
   export GDK_BACKEND=x11
   export QT_QPA_PLATFORM=xcb
   export PIXMAN_USE_RGA=1
   exec /usr/bin/cpis-panel-service --ini /etc/cpis/isp.ini --type dbus
   ```
   也就是说：**它从不使用 Fcitx 5 的 UI**，候选框永远是一个 X11 override-redirect 窗口。在 Wayland 会话里只能靠 XWayland 活着，跟光标走、缩放、多屏都会是问题——这正是你笔记里“候选框不跟随/不显示”的根因所在。
2. **面板拿不到 display 时会 SIGSEGV，并被 D-Bus 无限重拉**。我第一轮跑（`dbus-daemon` 环境里没有 `DISPLAY`）时：
   ```
   Gtk-WARNING: cannot open display: :0
   ERROR: dbus error: [Process com.cpis.panel received signal 11]
   ```
   每 ~90 ms 重试一次，日志刷到 200 KB+。真机上表现为：风扇狂转、输入毫无反应。**注意：真实桌面里 `dbus-daemon`（systemd --user）不一定带着 `DISPLAY/WAYLAND_DISPLAY`**，这是一个真实的踩坑点。
3. **按键模拟器模块名对不上**：插件要找 `libcpis-module-keystroke-simulator-xinput.so`，包里只有 `-linux.so` / `-xtst.so`：
   ```
   ERROR: open ks module failed: [(nil)], keystroke simulator for linux initialization failed, ret: [-6]
   ```
   不致命，但说明这套二进制在非 openKylin 环境里本来就有路径假设。
4. **有许可证校验器**（`license.signed.xml` + `pubkey.pem`，`verifier.cpp` 里带 `now sec / start / clk` 时钟判断）。我这边返回 `reuslt: [0]`（未判失败），但语义未知，理论上存在时间/机器相关的失效风险，长期用要留意。
5. 重打包者自己在 README 里也写了：**只验证了包结构和链接，不保证所有 Wayland 应用兼容**，并列出上游 bug“候选词数字键错位”。

---

## 5. 对你的方案的最终判断

| 判断 | 结论 |
|---|---|
| “旧官方搜狗改不成 Fcitx 5” | ✅ 正确，但**不是**因为“依赖冲突”，而是因为它是 Fcitx 4 插件 + X11 |
| “搜狗 NG 是唯一现实路径” | ✅ 基本正确（CPIS 桥接确实是给 Fcitx 5 写的） |
| “方式 A 门槛最低” | ✅ 且**实测能装能跑**；X11 下真能用 |
| “方式 A 在 Wayland 也可用” | ❓ **未证实**。沙箱里四种组合全失败，但沙箱本身也画不出候选窗 → 需真机验证 |
| “方式 B 更可控” | ⚠️ 在 Ubuntu 上**没有额外收益**：方式 B 就是把方式 A 手工做一遍（解 7 个 deb + 一个 `libcpis-module-im-sogou-ime-ng-fcitx5-kylin-desktop.so -> ../cpis-module-im-fcitx5.so` 符号链接）。除非你要改 `isp.ini`（比如把面板换成 wayland 后端）才值得 |

**推荐动作（按顺序）**：

1. 真机上装方式 A 的 deb（装完 `im-config -n fcitx5`，注销重登，在 Fcitx 5 配置里取消“仅显示当前语言”，添加“搜狗输入法NG麒麟桌面版”）。
2. **先切到 “Ubuntu on Xorg” 会话验证**——按我这边的结果，这条路径基本是能用的，可以立刻确认“包没坏、词库没坏”。
3. 再切回 Wayland 测同样的操作。如果候选框不出现，把 `~/.com.cpis.panel.log` 抓出来看有没有 `signal 11` / `cannot open display`；也可以试着把 `/usr/bin/com.cpis.panel.service.start.sh` 里的 `GDK_BACKEND=x11` 改成 `wayland`（我这边改了也没救，但值得一试）。
4. 想稳，就在 Wayland 会话继续用 Fcitx 5 自带拼音（`fcitx5-chinese-addons`），把搜狗 NG 只在 Xorg 会话里用；或者干脆锁 Xorg 会话。
5. 回滚：`sudo apt remove sogou-ime-ng-fcitx5-ubuntu && sudo apt install fcitx5-chinese-addons && im-config -n fcitx5`，重登。

**关于 GTK 4 的 `GTK_IM_MODULE`（第一轮判断有误，已修正）**：GTK 4 目录里只有 `libim-fcitx5.so`，但 GTK 4 是按模块 ID 匹配的，`GTK_IM_MODULE=fcitx` 照样会加载它（strace 实测）。所以**不需要**把 `fcitx` 改成 `fcitx5`。

---


---

# 第二轮（追加）：换用**真机的 Mutter 50.1** 复测 —— 结论反转

第一轮用 sway 当合成器，测出「Wayland 下没有候选窗」。这一轮把合成器换成 **Mutter 50.1**（与你机器同版本，`mutter --headless --wayland`，实测 `wayland-info` 的 globals 与真机一致：有 `zwp_text_input_manager_v3`，**没有** `zwp_input_method_manager_v2`），再跑同一套 CPIS。

## 结果：Mutter 下 CPIS 完全正常

* Fcitx 5 判定 `Using Wayland native input method protocol: 0` —— **与真机完全相同**
* 输入 `nihao`：候选窗 **575×76** 在 (329,385) 创建并 `IsViewable`
* 空格上屏：输入框内容变成 **你好**
* 候选窗内容（直接抓的 X11 窗口像素，`screenshots/05-mutter-candidate-window.png`）：

    预编辑 ni'hao
    1.你好  2.你号  3.拟好  4.倪好  5.倪浩  6.泥蒿

## 所以第一轮的失败是**沙箱合成器的锅**

sway 实现了 `zwp_input_method_manager_v2`，Fcitx 5 于是进入「Wayland 原生输入法协议」模式，按键被 Fcitx 5 抢走、由它负责画 UI；而 CPIS 只肯在自己的 X11 面板里画候选窗 → 按键被吞、什么都不显示。
你机器上的 Mutter **没有**这个协议，Fcitx 5 只能走「客户端 im 模块 + X11 候选窗」的老路，而这条路上 CPIS 是通的。

也就是说：**不需要任何补丁**。我在这一轮还试过并排除了这些"修复"：

| 试过的改法 | 结果 |
|---|---|
| 把 CPIS 面板的 `GDK_BACKEND=x11` 改成 `wayland` | 无效（sway 下依旧没窗）；Mutter 下没必要 |
| `fcitx5 --disable wayland,waylandim` | 无效且有害（Wayland 客户端拿不到 IC） |
| 手动创建 portal 输入上下文（`org.fcitx.Fcitx.InputMethod1.CreateInputContext`） | 能建 IC、按键 `handled=True`，但我的假客户端拿不到 commit 信号 —— 属于测试桩问题，不是产品问题 |

## 仍然没验到的一件事（如实说明）

**原生 Wayland 客户端里打字**这一步，沙箱里没有可靠的按键注入手段：

* `wtype` 要 `wlr-virtual-keyboard`，Mutter 不提供；
* `Gdk.test_simulate_key()` 在 Wayland 后端是空操作；
* Mutter 的 `RemoteDesktop` 注入需要 portal/EIS 握手，headless 下 `CreateSession` 拿不到可用对象。

不过 CPIS 只依赖两样东西：**按键**和**光标矩形**，两者都由 Fcitx 5 的同一套 IC API 提供（`ProcessKeyEvent` / `SetCursorRectV2`），与客户端是 X11 还是 Wayland 无关；Mutter 下这条通路已被证明可用（XWayland 客户端就是走它拿到 rect 的）。所以我的判断是**大概率可用**，但仍建议你真机试一次。

## 真机预估上调

| 项目 | 第一轮估计 | 现在 |
|---|---|---|
| X11(XWayland) 应用出候选窗 | — | **已验证可用** |
| 原生 Wayland 应用出候选窗 | 20–35% | **约 70–80%**（同一套 IC 通路，沙箱无法直接验证） |
| 候选窗跟随光标/多屏/缩放 | 高风险 | 中风险（rect 由客户端上报，X11 面板按全局坐标摆放） |

## 顺带纠正一个之前的说法

GTK 4 在 26.04 上 `GTK_IM_MODULE=fcitx` 是**能用的**：strace 显示它照样加载 `/usr/lib/x86_64-linux-gnu/gtk-4.0/4.0.0/immodules/libim-fcitx5.so`（GTK 4 按模块 ID 匹配，不是按文件名），不需要改成 `fcitx5`。

## 真机操作（低风险试法）

```bash
sudo apt install ./sogou-ime-ng-fcitx5-ubuntu_*_amd64.deb
fcitx5 -r                     # 或注销重登，否则新 addon 不加载
# Fcitx 5 配置 → 取消“仅显示当前语言” → 添加“搜狗输入法NG麒麟桌面版”
# 切到搜狗，随便找个 GTK 应用打 nihao 看有没有候选窗
# 不行就回滚：
sudo apt remove sogou-ime-ng-fcitx5-ubuntu && sudo apt install fcitx5-chinese-addons && fcitx5 -r
```

若某个 **Wayland 原生应用**里确实出不来候选窗、而 X11 应用正常，最省事的兜底是让该应用走 XWayland：`GDK_BACKEND=x11 your-app`（或整体改用 “Ubuntu on Xorg” 会话）。

> 说明：本轮所有测试都在 `/tmp/sandbox` 的独立根文件系统里完成，**没有在真机上安装任何东西**，也没有使用 sudo 修改系统。

## 6. 本次没验证到的

* GNOME Shell / Mutter 下的真实行为（沙箱用的是 sway，没有 Mutter 的 XWayland 细节）。
* 长时间稳定性、休眠唤醒、多屏/缩放、Firefox/Chrome/Electron/Qt 应用。
* 数字键选词错位等上游 bug 的复现（我只测了空格上屏和数字键路径的一部分）。
* 许可证校验在改系统时间/换机器后的行为。

---

## 7. 复现方式

```bash
cd scripts
./build-rootfs.sh            # 建 Ubuntu 26.04 沙箱根文件系统（免 root，走清华源）
./fetch-debs.sh              # 拉 7 个 openKylin deb（阿里云，sha256 校验）
./fetch-repack.sh            # 拉方式 A 的重打包 deb（gh-proxy，SHA256SUMS 校验）
./install-sogou.sh           # 沙箱内安装 + 打印接入点
./run-x11.sh                 # X11 会话测试（Xvfb+openbox）：截图落在 /tmp/sandbox/shots
./run-wayland.sh             # Wayland 会话测试（headless sway+XWayland）
```

`run-*.sh` 里的 `PANEL_BACKEND=x11|wayland` 可切换 CPIS 面板的 GTK 后端，`APP_BACKEND=x11|wayland`（`run-wayland.sh` 衍生版）可切换客户端类型。

---

# 第三轮：**真机实测**（Ubuntu 26.04.1 / GNOME Shell 50.1 / Mutter 18 / Wayland）

在你的机器上实际安装并验证，结论：**能用，而且原生 Wayland 客户端也正常。**

## 安装与生效

```bash
sudo apt install ./sogou-ime-ng-fcitx5-ubuntu_10.0.9.0.6-20231128000607+ubuntu26.04.1_amd64.deb
```

* 只新增 1 个包，卸载 0、升级 0（`apt --dry-run` 先确认过）
* 装后 `fcitx5-remote -e` + `fcitx5 -d` 重启，`~/.config/fcitx5/profile` 里加入 `sogou-ime-ng-fcitx5-kylin-desktop`（`DefaultIM` 仍是 `rime`，没动你的默认）

## 实测证据

切到搜狗 NG 后三条进程全部拉起，稳定无崩溃：

```
cpis-panel-service --ini /etc/cpis/isp.ini --type dbus     (0.1% CPU)
cpis-engine-service --ini /etc/cpis/ise.ini --type dbus
ISE_NODE --ini=.../ise.ini --type thrift
```

* `grep -c "received signal 11" ~/.com.cpis.panel.log` → **0**（没有沙箱首轮那种崩溃重拉）
* 面板窗口：状态条 `205x30` + 候选窗 `557x81`，用后自动 `IsUnMapped`
* **原生 Wayland GTK4 客户端**（`GDK_BACKEND` 未设置）输入 `nihao` → 候选出现 → 空格上屏，测试程序日志留下 `TEXT:你好`

这补上了沙箱里唯一没验成的那一环：**原生 Wayland 应用也可用**（沙箱里没法给 Wayland 客户端注入按键：XTEST 在 mutter 会话里到不了 X 客户端，`wtype` 需要 wlr-virtual-keyboard，mutter 不提供）。

## 当前机器状态

| 项 | 状态 |
|---|---|
| 包 | `sogou-ime-ng-fcitx5-ubuntu 10.0.9.0.6-20231128000607+ubuntu26.04.1`，约 300 MB |
| 输入法组 | 已加入，`DefaultIM` 仍是 `rime`；切换用 Ctrl+Space |
| 备份 | `~/sogou-ng-rollback/profile` |
| 为测试装的附加包 | `xdotool`、`x11-apps`、`netpbm`（可删） |

## 回滚

```bash
fcitx5-remote -s rime              # 立刻切回雾凇，不用卸载
sudo apt remove sogou-ime-ng-fcitx5-ubuntu   # 彻底卸载
sudo apt remove xdotool x11-apps netpbm      # 可选：清掉测试用工具
cp ~/sogou-ng-rollback/profile ~/.config/fcitx5/profile && fcitx5 -r   # 还原输入法组
```

## 仍需你自己盯的点

* 候选词**数字键选词**是否错位（上游已知问题，我没测）
* 多屏/高缩放下的候选窗跟随
* Firefox/Chrome/Electron/Qt 应用里的表现
* 该二进制是 2023 年闭源产物，含许可证校验器，长期可用性无保证

---

# 第四轮：把搜狗 NG 设为**默认输入法**

`~/.config/fcitx5/profile` 现在的组结构（`fcitx5-remote -e` → 改文件 → `fcitx5 -d`，避免被退出时的落盘覆盖）：

```ini
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=sogou-ime-ng-fcitx5-kylin-desktop   # ← 原来是 rime

[Groups/0/Items/0]  Name=keyboard-us
[Groups/0/Items/1]  Name=sogou-ime-ng-fcitx5-kylin-desktop
[Groups/0/Items/2]  Name=rime
```

D-Bus 复核：`InputMethodGroupInfo("Default")` → `"us" 3 "keyboard-us" "" "sogou-ime-ng-fcitx5-kylin-desktop" "" "rime" ""`

行为（实测）：新窗口的 IC 默认**未激活**（`fcitx5-remote` = 1，`-n` = keyboard-us），按一次 **Ctrl+Space** 激活后就是**搜狗 NG**；再按回到英文直通。这是 fcitx5 的标准行为（`ActiveByDefault` 未开启）。

若要"打开就能直接打中文、不用按 Ctrl+Space"，新建 `~/.config/fcitx5/config`：

```ini
[Behavior]
ActiveByDefault=True
```

备份：`~/sogou-ng-rollback/profile.before-default`
