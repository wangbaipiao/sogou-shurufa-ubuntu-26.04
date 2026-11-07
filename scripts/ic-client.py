import gi, sys, time
from gi.repository import Gio, GLib

IMK = sys.argv[1] if len(sys.argv) > 1 else 'pinyin'
KEYS = [('n', 0x6e, 57), ('i', 0x69, 31), ('h', 0x68, 43), ('a', 0x61, 38), ('o', 0x6f, 32)]

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

def call(dest, path, iface, method, args=None, sig=None):
    return bus.call_sync(dest, path, iface, method, args,
                         GLib.VariantType.new(sig) if sig else None,
                         Gio.DBusCallFlags.NONE, -1, None)

res = call('org.fcitx.Fcitx5', '/org/freedesktop/portal/inputmethod',
           'org.fcitx.Fcitx.InputMethod1', 'CreateInputContext',
           GLib.Variant('(a(ss))', ([('display', 'wayland:'), ('program', 'testapp')],)),
           '(oay)')
ic_path, token = res.unpack()
print('IC:', ic_path, flush=True)

events = []
def on_signal(conn, sender, path, iface, signal, params):
    events.append((signal, params.print_(False) if params else ''))
bus.signal_subscribe('org.fcitx.Fcitx5', None, None, ic_path, None,
                     Gio.DBusSignalFlags.NONE, on_signal)

def ic(method, sig, vals):
    bus.call_sync('org.fcitx.Fcitx5', ic_path, 'org.fcitx.Fcitx.InputContext1', method,
                  GLib.Variant(sig, vals), None, Gio.DBusCallFlags.NONE, -1, None)

ic('SetSupportedCapability', '(t)', (0,))
ic('SetCapability', '(t)', (0,))
ic('SetCursorRectV2', '(iiiid)', (300, 300, 4, 20, 1.0))
ic('FocusIn', '()', ())
time.sleep(0.8)
call('org.fcitx.Fcitx5', '/controller', 'org.fcitx.Fcitx.Controller1', 'SetCurrentIM',
     GLib.Variant('(s)', (IMK,)))
time.sleep(0.8)
print('FocusIn + SetCurrentIM ->', IMK, flush=True)
print('建立会话后事件:', events[:], flush=True)

for name, keysym, keycode in KEYS:
    r = bus.call_sync('org.fcitx.Fcitx5', ic_path, 'org.fcitx.Fcitx.InputContext1',
                      'ProcessKeyEventBatch', GLib.Variant('(uuubu)', (keysym, keycode, 0, False, 0)),
                      GLib.VariantType.new('(a(uv)b)'), Gio.DBusCallFlags.NONE, -1, None).unpack()
    print('key %s handled=%s' % (name, r), flush=True)
    time.sleep(0.25)

time.sleep(0.6)
print('--- 预编辑后事件 ---')
for s, p in events: print(' ', s, p[:120])
events.clear()

r = bus.call_sync('org.fcitx.Fcitx5', ic_path, 'org.fcitx.Fcitx.InputContext1',
                  'ProcessKeyEvent', GLib.Variant('(uuubu)', (0x20, 65, 0, False, 0)),
                  GLib.VariantType.new('(b)'), Gio.DBusCallFlags.NONE, -1, None).unpack()[0]
print('key space handled=%s' % r, flush=True)
time.sleep(0.8)
print('--- 空格后事件 ---')
for s, p in events: print(' ', s, p[:160])
