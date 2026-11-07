import gi, os
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk

STATE = '/mnt/shots/entry-state.txt'
open(STATE, 'w').write('')

def on_activate(app):
    win = Gtk.ApplicationWindow(application=app, title="IME Test")
    win.set_default_size(640, 200)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    entry = Gtk.Entry()
    entry.set_hexpand(True)
    box.append(Gtk.Label(label="GTK4 Entry:"))
    box.append(entry)
    win.set_child(box)
    win.present()
    entry.grab_focus()

    def changed(e):
        with open(STATE, 'w') as f:
            f.write(e.get_text() + '\n')
    entry.connect('changed', changed)

app = Gtk.Application(application_id="org.test.IME")
app.connect('activate', on_activate)
app.run(None)
