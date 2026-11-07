import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk

def on_activate(app):
    win = Gtk.ApplicationWindow(application=app, title="IME Test")
    win.set_default_size(640, 220)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    box.set_margin_top(12); box.set_margin_start(12); box.set_margin_end(12)
    entry = Gtk.Entry()
    entry.set_hexpand(True)
    entry.set_placeholder_text("type here")
    box.append(Gtk.Label(label="GTK4 Entry:"))
    box.append(entry)
    win.set_child(box)
    win.present()
    entry.grab_focus()

app = Gtk.Application(application_id="org.test.IME")
app.connect('activate', on_activate)
app.run(None)
