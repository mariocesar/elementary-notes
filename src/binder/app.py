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

import os
from gi.repository import Gtk, Gdk, Gio, GLib


class Persistent(Gtk.Application):
    app_name = None

    def do_activate(self):
        assert self.app_name is not None, 'define a name for the application'
        super(Persistent, self).do_activate()

        self.data_dir = os.path.join(GLib.get_user_data_dir(), self.app_name)


class Configurable(Gtk.Application):
    namespace = None

    def do_activate(self):
        assert self.name is not None, 'define a namespace for the application'
        super(Persistent, self).do_activate()

        self.settings = Gio.Settings(self.namespace)


class Styled(Gtk.Application):
    stylesheet_dirs = []

    def do_activate(self):
        assert self.name is not None, 'define a name for the application'
        super(Persistent, self).do_activate()

        css_provider = Gtk.CssProvider()

        for path in self.stylesheet_dirs:
            css_provider.load_from_data(Gio.File.new_for_path())

        screen = Gdk.Screen.get_default()

        context = self.window.get_style_context()
        context.add_provider_for_screen(
            screen, css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
