#!/usr/bin/python
# encoding: utf-8

"""
LICENSE:

    Copyright (C) 2014 Mario César Señoranis Ayala <mariocesar@creat1va.com>

    This program or library is free software; you can redistribute it
    and/or modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 3 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General
    Public License along with this library; if not, write to the
    Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301 USA.
"""

import sys
import os
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkSource", "3.0")

from gi.repository import Gtk, GtkSource, Gdk, Gio, GLib


class NoteWindow(Gtk.Window):
    styles = """
    #note_window, #grid, #text_view, #scroll_view {
        background: #FFFFE0;
    }
    #text_view text {
        background: #FFFFE0;
    }

    #headerbar {
        background-color: #FFFFE0;
        background-image: none;
        border-bottom-color: #FFFFE0;
        box-shadow: none;
    }
    """

    def __init__(self, app):
        Gtk.Window.__init__(self)
        self.app = app

        self.set_application(app)
        self.set_name("note_window")
        self.set_title("Note")
        self.set_resizable(True)
        self.set_size_request(460, 500)
        self.set_gravity(Gdk.Gravity.SOUTH_EAST)

        # Signals
        self.restore_position()
        self.connect("delete_event", self.save_position)

        # HeaderBar
        hb = Gtk.HeaderBar()
        hb.set_name("headerbar")
        hb.set_has_subtitle(False)
        hb.set_show_close_button(True)
        hb.set_decoration_layout("close:")
        hb.set_title("Note")
        self.set_titlebar(hb)

        # Styles
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(self.styles.encode("UTF-8"))

        style_context = self.get_style_context()
        style_context.add_class("rounded")
        style_context.add_class("default-decoration")
        style_context.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        # Grid
        self.grid = Gtk.Grid()
        self.grid.set_name("grid")

        self.add(self.grid)

        # Text View
        self.textview = GtkSource.View()
        self.textview.set_name("text_view")
        self.textview.set_insert_spaces_instead_of_tabs(True)
        self.textview.set_auto_indent(True)
        self.textview.set_indent_on_tab(True)
        self.textview.set_smart_backspace(True)
        self.textview.set_smart_home_end(True)
        self.textview.set_wrap_mode(Gtk.WrapMode.WORD)
        self.textview.set_left_margin(15)
        self.textview.set_right_margin(15)
        self.textview.set_top_margin(15)
        self.textview.set_bottom_margin(15)

        lang_manager = GtkSource.LanguageManager().get_default()
        language = lang_manager.get_language("markdown")

        stylemanager = GtkSource.StyleSchemeManager.get_default()
        style_scheme = stylemanager.get_scheme('solarized-light')

        self.textbuffer = GtkSource.Buffer.new_with_language(language)
        self.textbuffer.set_style_scheme(style_scheme)
        self.textbuffer.connect("changed", self.on_text_buffer_change)
        self.textview.set_buffer(self.textbuffer)

        self.checkout_text_buffer()

        # Scroll view
        scrolledwindow = Gtk.ScrolledWindow()
        scrolledwindow.margin = 10
        scrolledwindow.set_name("scroll_view")
        scrolledwindow.set_hexpand(True)
        scrolledwindow.set_vexpand(True)
        scrolledwindow.add(self.textview)

        self.grid.attach(scrolledwindow, 0, 1, 3, 1)

    def checkout_text_buffer(self):
        if os.path.exists(self.app.notes_file_path):
            with open(self.app.notes_file_path, "r+") as f:
                self.textbuffer.set_text(f.read(), f.tell())
        else:
            open(self.app.notes_file_path, "a").close()

    def commit_text_buffer(self):
        text = self.textbuffer.get_text(
            self.textbuffer.get_start_iter(), self.textbuffer.get_end_iter(), True
        )

        with open(self.app.notes_file_path, "w+") as f:
            f.write(text)

    def restore_position(self):
        try:
            x, y = self.app.settings["window-position"]
            width, height = self.app.settings["window-size"]
        except ValueError:
            self.set_position(Gtk.WindowPosition.CENTER)
        else:
            self.resize(width, height)
            self.move(x, y)

    def save_position(self, widget, event):
        self.app.settings["window-size"] = widget.get_size()
        self.app.settings["window-position"] = widget.get_position()

    def on_text_buffer_change(self, widget):
        self.commit_text_buffer()


class Application(Gtk.Application):
    data_dir = os.path.join(GLib.get_user_data_dir(), "notes")

    def __init__(self, *args, **kwargs):
        self.settings = Gio.Settings("org.gnome.notes")
        self.notes_file_path = os.path.expanduser("~/Dropbox/Notes/Notes.md")

        if not os.path.exists(self.data_dir):
            os.makedirs(self.data_dir)

        Gtk.Application.__init__(self, *args, **kwargs)

    def do_activate(self):
        windows = self.get_windows()

        if windows:
            for window in windows:
                window.present()
                window.activate()
        else:
            window = NoteWindow(self)
            window.show_all()
            window.present()
            window.activate()

            self.add_window(window)


if __name__ == "__main__":
    application = Application()
    application.run(sys.argv)
