#!/bin/bash
L=/mnt/shots
MODE=${PANEL_BACKEND:-x11}
TAG=$MODE
exec 2>&1
set -x
export PATH=/usr/local/sbin:$PATH
export XDG_RUNTIME_DIR=/run/user/0
rm -rf "$XDG_RUNTIME_DIR"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
# patch panel backend
sed -i "s/^export GDK_BACKEND=.*/export GDK_BACKEND=$MODE/" /usr/bin/com.cpis.panel.service.start.sh
grep GDK_BACKEND /usr/bin/com.cpis.panel.service.start.sh

export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
sway -c /mnt/sb/sway.conf -d > $L/sway-$TAG.log 2>&1 &
for i in $(seq 1 80); do ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1 && break; sleep 0.25; done
export WAYLAND_DISPLAY=$(basename "$(ls "$XDG_RUNTIME_DIR"/wayland-* | head -1)")
export SWAYSOCK=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.* 2>/dev/null | head -1)
sleep 1.5
swaymsg exec 'env | grep -E "^(DISPLAY)=" > /mnt/shots/sway-env.txt' >/dev/null
for i in $(seq 1 40); do [ -s $L/sway-env.txt ] && break; sleep 0.25; done
export DISPLAY=$(grep '^DISPLAY=' $L/sway-env.txt | cut -d= -f2-)
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address)
echo "MODE=$MODE WL=$WAYLAND_DISPLAY DISPLAY=$DISPLAY"

printf '[Behavior]\nActiveByDefault=True\n' > /root/.config/fcitx5/config
cat > /root/.config/fcitx5/profile <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=sogou-ime-ng-fcitx5-kylin-desktop

[Groups/0/Items/0]
Name=sogou-ime-ng-fcitx5-kylin-desktop
Layout=

[Groups/0/Items/1]
Name=keyboard-us
Layout=

[GroupOrder]
0=Default
EOF

export GTK_IM_MODULE=fcitx5 QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx GTK_A11Y=none
fcitx5 -d --verbose "default=5" > $L/fcitx5-$TAG.log 2>&1
sleep 4
python3 /mnt/sb/test-entry.py > $L/app-$TAG.log 2>&1 &
APP=$!
sleep 3
fcitx5-remote -s sogou-ime-ng-fcitx5-kylin-desktop
sleep 1
wtype -d 150 'nihao'
sleep 1.5
grim $L/wl-$TAG.png
echo "########## Xwayland-visible windows ##########"
for id in $(xdotool search --onlyvisible --class '.' 2>/dev/null | head -10); do
  echo "ID=$id NAME=$(xdotool getwindowname $id 2>/dev/null) $(xdotool getwindowgeometry $id 2>/dev/null | tr '\n' ' ')"
done
echo "########## panel windows seen ##########"
grep -ao "wndname= [a-z0-9_]*" /root/.com.cpis.panel.log 2>/dev/null | sort | uniq -c
echo "########## AcquireWindowRect / Move composition ##########"
grep -a "Move  wndname\|AcquireWindowRect" /root/.com.cpis.panel.log 2>/dev/null | grep -ao "wndname= [a-z0-9_]*\s*position= [-0-9, ]*" | head -8
xdotool key space
sleep 1.5
grim $L/wl-$TAG-commit.png
kill -0 $APP && echo app_running
set +x
