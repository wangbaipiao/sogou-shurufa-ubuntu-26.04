import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

win = Gtk.Window(title="IME Test GTK3")
win.set_default_size(640, 200)
box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
box.set_margin_top(12); box.set_margin_start(12); box.set_margin_end(12)
entry = Gtk.Entry()
entry.set_hexpand(True)
entry.set_placeholder_text("type here")
box.pack_start(Gtk.Label(label="GTK3 Entry:"), False, False, 0)
box.pack_start(entry, False, False, 0)
win.add(box)
win.connect("destroy", Gtk.main_quit)
win.show_all()
entry.grab_focus()
Gtk.main()
