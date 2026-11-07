#!/bin/bash
L=/mnt/shots
exec 2>&1
set -x
export PATH=/usr/local/sbin:$PATH
export XDG_RUNTIME_DIR=/run/user/0
rm -rf "$XDG_RUNTIME_DIR"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export DISPLAY=:99
Xvfb :99 -screen 0 1280x800x24 > $L/xvfb.log 2>&1 &
for i in $(seq 1 40); do xdotool getdisplaygeometry >/dev/null 2>&1 && break; sleep 0.25; done
openbox > $L/openbox.log 2>&1 &
sleep 1.5
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address)

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

export GTK_IM_MODULE=fcitx5 QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx GTK_A11Y=none GDK_BACKEND=x11
fcitx5 -d --verbose "default=4" > $L/fcitx5.log 2>&1
sleep 4
python3 /mnt/sb/test-entry.py > $L/app.log 2>&1 &
APP=$!
sleep 3
xdotool search --onlyvisible --name "IME Test" | head -3
fcitx5-remote -s sogou-ime-ng-fcitx5-kylin-desktop
sleep 1
xdotool type --delay 150 'nihao'
sleep 1
scrot $L/x11-preedit.png
echo "########## visible windows ##########"
for id in $(xdotool search --onlyvisible --class '.' 2>/dev/null | head -20); do
  echo "ID=$id NAME=$(xdotool getwindowname $id 2>/dev/null) GEO=$(xdotool getwindowgeometry $id 2>/dev/null | tr '\n' ' ')"
done
xdotool key space
sleep 1.5
scrot $L/x11-commit.png
echo "########## panel log tail ##########"
tail -6 /root/.com.cpis.panel.log 2>/dev/null | cut -c1-180
echo "########## window names in panel log ##########"
grep -ao "wndname= [a-z0-9_]*" /root/.com.cpis.panel.log | sort | uniq -c
kill -0 $APP && echo app_running
set +x
