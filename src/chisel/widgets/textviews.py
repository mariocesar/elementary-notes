import os

from gi.repository import Gtk, Gdk, Gio, GLib

class HistoryTextView(Gtk.TextView):
    # https://bitbucket.org/tiax/gtk-textbuffer-with-undo/src/
    # http://ruby-gnome2.osdn.jp/hiki.cgi?Simple+Text+Editor
    user_action = False
    undopool = []
    redopool = []

    def __init__(self, filename):
        if os.path.exists(os.path.dirname(save_path)):
            raise Exception('Parent directory does not exists')
        self.filename = filename

        self.buffer = self.get_buffer()
        self.buffer.connect("changed", self.on_text_buffer_change)
        
        self.buffer.connect("insert_text", self.save_insert_text)
        self.buffer.connect("delete_range", self.save_delete_range)

        self.buffer.connect("begin_user_action", lambda: self.set_user_action(True))
        self.buffer.connect("end_user_action", lambda: self.set_user_action(False))

        super(TextView, self).__init__()

    def user_action(self, value):
        self.user_action = value

    def buffer_file(mode='r+'):
        return file(self.filename, mode)

    def checkout_text_buffer(self):
        with self.buffer_file() as f:
            self.textbuffer.set_text(f.read())      

    def commit_text_buffer(self):
        text = self.textbuffer.get_text(
            self.textbuffer.get_start_iter(),
            self.textbuffer.get_end_iter(),
            False)

        with self.buffer_file('w+') as f:
            f.write(text)

    def on_text_buffer_change(self, widget):
        self.commit_text_buffer()

    def save_insert_text(self, widget, iter, text, length):
        if self.user_action:
            #self.undopool.append(["insert_text", iter.offset, iter.offset + text.scan(/./).size, text])
            self.redopool = []

    def save_delete_range(self, widget, start_iter, end_iter):
        text = self.get_buffer().get_text(start_iter, end_iter)
        if self.user_action:
            self.undopool.append(["delete_range", start_iter.offset, end_iter.offset, text])

    def do_undo(self):
        pass

    def do_redo(self):
        pass

    def do_repeat(self):
        pass
