from gi.repository import Gtk, Gdk, Gio, GLib


class ReminiscentWindow(Gtk.Window):
    default_width = 460
    default_height = 500

    def __init__(self, application):
        super(ReminiscentWindow, self).__init__()
        self.application = application
        self.set_resizable(True)

        self.restore_position()
        self.restore_size()

        self.connect('delete_event', self.save_position)
        self.connect('delete_event', self.save_size)


    def save_position(self, widget, event):
        self.application.settings['window-position'] = widget.get_position()

    def save_size(self, widget, event):
        self.application.settings['window-size'] = widget.get_position()

    def restore_position(self):
        try:
            x, y = self.application.settings['window-position']
        except ValueError:
            self.set_position(Gtk.WindowPosition.CENTER)
        else:
            self.move(x, y)

    def restore_size(self):
        try:
            w, h = self.application.settings['window-size']
        except ValueError:
            self.set_size_request(self.default_width, self.default_height)
        else:
            self.size(w, h)
