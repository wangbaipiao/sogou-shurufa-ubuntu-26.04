#!/bin/bash
L=/mnt/shots
APPMODE=${APPMODE:-x11}
IMK=${IMK:-sogou-ime-ng-fcitx5-kylin-desktop}
TAG=${TAG:-mutter}
exec 2>&1
set -x
export PATH=/usr/local/sbin:$PATH
export XDG_RUNTIME_DIR=/run/user/0
rm -rf "$XDG_RUNTIME_DIR"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export LIBGL_ALWAYS_SOFTWARE=1 XDG_CURRENT_DESKTOP=ubuntu:GNOME
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address)
mutter --headless --wayland --devkit --virtual-monitor 1280x800 > $L/mutter-$TAG.log 2>&1 &
for i in $(seq 1 80); do wayland-info >/dev/null 2>&1 < /dev/null [ -S "$XDG_RUNTIME_DIR/wayland-0" ] && break; [ -S "$XDG_RUNTIME_DIR/wayland-0" ] && break; sleep 0.25; done
sleep 5
ENVP=$(busctl --user get-property org.gnome.Mutter.Devkit /org/gnome/Mutter/Devkit org.gnome.Mutter.Devkit Env 2>/dev/null)
echo "DEVKIT_ENV=$ENVP"
export WAYLAND_DISPLAY=$(echo "$ENVP" | grep -o 'WAYLAND_DISPLAY" "wayland-[0-9]*' | grep -o 'wayland-[0-9]*')
export DISPLAY=$(echo "$ENVP" | grep -o 'DISPLAY" ":[0-9]*' | grep -o ':[0-9]*')
export XAUTHORITY=$(echo "$ENVP" | sed -n 's/.*"XAUTHORITY" "\([^"]*\)".*/\1/p')
echo "WL=$WAYLAND_DISPLAY DISPLAY=$DISPLAY XAUTH=$XAUTHORITY APPMODE=$APPMODE IMK=$IMK"
# 与真机一致：GTK_IM_MODULE=fcitx
export GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx GTK_A11Y=none
case "$APPMODE" in x11) export GDK_BACKEND=x11;; wayland) unset GDK_BACKEND;; esac
printf '[Behavior]\nActiveByDefault=True\n' > /root/.config/fcitx5/config
cat > /root/.config/fcitx5/profile <<EOF
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=$IMK

[Groups/0/Items/0]
Name=$IMK
Layout=

[Groups/0/Items/1]
Name=keyboard-us
Layout=

[GroupOrder]
0=Default
EOF
fcitx5 -d --verbose "default=4" > $L/fcitx5-$TAG.log 2>&1
sleep 4
python3 /mnt/sb/test-entry-state.py > $L/app-$TAG.log 2>&1 &
APP=$!
sleep 4
echo "== 当前 IM: $(fcitx5-remote -n)"
fcitx5-remote -s "$IMK"; echo "switch rc=$?"; sleep 1
echo "== 切后 IM: $(fcitx5-remote -n)"
xdotool type --delay 150 'nihao'
sleep 2
echo "== entry state (预编辑阶段) =="; cat $L/entry-state.txt
echo "== CPIS 所有 X11 窗口（含未映射）=="
for id in $(xdotool search --class 'cpis' 2>/dev/null); do
  echo "ID=$id NAME=$(xdotool getwindowname $id 2>/dev/null) $(xwininfo -id $id 2>/dev/null | grep -E 'Map State|Absolute upper-left|Width|Height' | tr '\n' ' ')"
done
echo "== 截取候选窗（xwd）=="
WID=""
for id in $(xdotool search --class 'cpis' 2>/dev/null); do
  w=$(xwininfo -id $id | awk '/Width:/{print $2}')
  h=$(xwininfo -id $id | awk '/Height:/{print $2}')
  s=$(xwininfo -id $id | awk '/Map State:/{print $3}')
  if [ "$s" = "IsViewable" ] && [ "${w:-0}" -gt 300 ]; then WID=$id; fi
done
echo "WID=$WID"
if [ -n "$WID" ]; then
  xwd -id $WID -out $L/cand.xwd && xwdtopnm < $L/cand.xwd > $L/cand.pnm && pnmtopng < $L/cand.pnm > $L/mutter-candidate.png && ls -la $L/mutter-candidate.png
fi

xdotool key space
sleep 2
echo "== entry state (空格后) =="; cat $L/entry-state.txt
echo "== CPIS 窗口（空格后）=="
for id in $(xdotool search --class 'cpis' 2>/dev/null); do
  echo "ID=$id NAME=$(xdotool getwindowname $id 2>/dev/null) $(xwininfo -id $id 2>/dev/null | grep -E 'Map State|Absolute upper-left|Width|Height' | tr '\n' ' ')"
done
echo "== panel log: 窗口名 =="; grep -ao "wndname= [a-z0-9_]*" /root/.com.cpis.panel.log 2>/dev/null | sort | uniq -c
echo "== panel log: rect/composition =="; grep -a "AcquireWindowRect\|Move  wndname\|composition" /root/.com.cpis.panel.log 2>/dev/null | cut -c1-160 | head -8
kill -0 $APP && echo app_running
set +x
