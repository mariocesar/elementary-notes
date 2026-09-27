public class Pad.NoteWindow : Gtk.ApplicationWindow {
    // Edits are saved once typing pauses, and at least this often while it goes on.
    const int64 SAVE_PAUSE = 500 * TimeSpan.MILLISECOND;
    const int64 SAVE_MAX_WAIT = 5 * TimeSpan.SECOND;

    public File file { get; private set; }
    // Shown as the window title.
    string file_name;
    public GtkSource.View view { get; private set; }
    GtkSource.Buffer buffer;
    // Says why the file couldn't be read or saved; hidden otherwise.
    Gtk.Revealer banner;
    Gtk.Label banner_label;
    uint save_source;
    // Monotonic times of the first and last edit waiting for save_source.
    int64 first_edit;
    int64 last_edit;
    // Whether a write is running; the file is never written twice at once.
    public bool saving { get; private set; }
    bool save_again;
    // Held from closing until the last write is done, so the app doesn't quit mid-write.
    GLib.Application? held;
    // Where the window was last closed, -1 when unknown.
    int saved_x;
    int saved_y;

    public NoteWindow (Application app, File file) {
        // Opens at a fixed size so niri floats it, then becomes resizable once shown.
        Object (application: app, title: file.get_basename (), resizable: false);
        int width, height;
        app.window_geometry (file, out width, out height, out saved_x, out saved_y);
        set_default_size (width, height);
        map.connect_after (() => Idle.add (() => {
            resizable = true;
            if (saved_x >= 0 && saved_y >= 0) move_to (saved_x, saved_y);
            return Source.REMOVE;
        }));
        this.file = file;
        file_name = file.get_basename ();
        add_css_class ("note");
        // Only a close button, on the side where the desktop puts it.
        var header = new Gtk.HeaderBar ();
        Gtk.Settings.get_default ().bind_property ("gtk-decoration-layout", header, "decoration-layout",
            BindingFlags.SYNC_CREATE, (binding, from, ref to) => {
                var layout = (string) from ?? "";
                to = "close" in layout.split (":")[0] ? "close:" : ":close";
                return true;
            });
        titlebar = header;

        // Highlighting follows the file name; notes, plain text and unknown files read as Markdown.
        var languages = GtkSource.LanguageManager.get_default ();
        var language = languages.guess_language (file_name, null) ?? languages.get_language ("markdown");
        buffer = new GtkSource.Buffer.with_language (language) {
            style_scheme = GtkSource.StyleSchemeManager.get_default ().get_scheme ("pad"),
        };
        view = new GtkSource.View.with_buffer (buffer) {
            monospace = true,
            insert_spaces_instead_of_tabs = true,
            auto_indent = true,
            indent_on_tab = true,
            smart_backspace = true,
            smart_home_end = GtkSource.SmartHomeEndType.BEFORE,
            wrap_mode = Gtk.WrapMode.WORD,
            left_margin = 15,
            right_margin = 15,
            top_margin = 15,
            bottom_margin = 15,
        };
        banner_label = new Gtk.Label ("") { wrap = true, xalign = 0 };
        banner_label.add_css_class ("banner");
        banner = new Gtk.Revealer () { child = banner_label };
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.append (banner);
        box.append (new Gtk.ScrolledWindow () { child = view, hexpand = true, vexpand = true });
        child = box;

        load ();
        buffer.changed.connect (() => {
            last_edit = get_monotonic_time ();
            if (save_source != 0) return;
            first_edit = last_edit;
            wait_to_save (SAVE_PAUSE);
        });
        // Switching away is a natural pause: save now.
        notify["is-active"].connect (() => {
            if (is_active || save_source == 0) return;
            Source.remove (save_source);
            save_source = 0;
            save.begin ();
        });
    }

    // One timeout per burst of typing: it goes back to sleep until the burst ends, instead of
    // being replaced on every key.
    void wait_to_save (int64 delay) {
        save_source = Timeout.add ((uint) ((delay + TimeSpan.MILLISECOND - 1) / TimeSpan.MILLISECOND), () => {
            var due = int64.min (last_edit + SAVE_PAUSE, first_edit + SAVE_MAX_WAIT);
            var now = get_monotonic_time ();
            if (now < due) {
                wait_to_save (due - now);
            } else {
                save_source = 0;
                save.begin ();
            }
            return Source.REMOVE;
        });
    }

    void load () {
        try {
            uint8[] contents;
            file.load_contents (null, out contents, null);
            if (!((string) contents).validate ()) throw new ConvertError.ILLEGAL_SEQUENCE ("not UTF-8 text");
            // Loading is not an edit that undo can take back.
            buffer.begin_irreversible_action ();
            buffer.text = (string) contents;
            buffer.end_irreversible_action ();
            buffer.set_modified (false);
        } catch (IOError.NOT_FOUND e) {
            // A new note; the file is created on the first save.
        } catch (Error e) {
            // Never overwrite a note that could not be read.
            warning ("Reading %s: %s", file.get_path (), e.message);
            view.editable = false;
            title = file_name + " (read only)";
            banner_label.label = "Pad couldn't read this file, so it won't change it: " + e.message;
            banner.reveal_child = true;
        }
    }

    // Writes the text off the main thread. A save asked for during a write runs right after it.
    async void save () {
        if (saving) {
            save_again = true;
            return;
        }
        saving = true;
        do {
            save_again = false;
            // Unmodified since the last save, or undone back to it.
            if (!buffer.get_modified ()) continue;
            // Edits made during the write mark the buffer modified again.
            buffer.set_modified (false);
            var bytes = new Bytes (buffer.text.data);
            try {
                try {
                    yield file.replace_contents_bytes_async (bytes, null, false, FileCreateFlags.NONE, null, null);
                } catch (IOError.NOT_FOUND e) {
                    file.get_parent ().make_directory_with_parents ();
                    yield file.replace_contents_bytes_async (bytes, null, false, FileCreateFlags.NONE, null, null);
                }
                title = file_name;
                banner.reveal_child = false;
            } catch (Error e) {
                // Kept modified: the next edit or closing tries again.
                warning ("Saving %s: %s", file.get_path (), e.message);
                title = file_name + " (not saved)";
                banner_label.label = "Not saved: %s. Pad tries again with your next edit.".printf (e.message);
                banner.reveal_child = true;
                buffer.set_modified (true);
                break;
            }
        } while (save_again);
        saving = false;
        if (held != null) held.release ();
        held = null;
    }

    public override bool close_request () {
        if (save_source != 0) Source.remove (save_source);
        save_source = 0;
        // The allocated size, since GTK stops updating the default size while tiled, and niri tiles every window.
        if (get_mapped () && !maximized && !fullscreened) {
            int x, y;
            get_position (out x, out y);
            ((Application) application).remember_geometry (file, get_width (), get_height (), x, y);
        }
        if (held == null) {
            held = application;
            held.hold ();
        }
        save.begin ();
        return base.close_request ();
    }

#if X11
    // GTK deprecates its X11 API as a whole since 4.18; the C function itself is fine.
    [CCode (cname = "gdk_x11_surface_get_xid", cheader_filename = "gdk/x11/gdkx.h")]
    extern static X.Window xid (Gdk.X11.Surface surface);
#endif

    // Only X11 lets a window know and set its own position; on Wayland the desktop places it,
    // and the position is -1.
    public void get_position (out int x, out int y) {
        x = y = -1;
#if X11
        var surface = get_surface () as Gdk.X11.Surface;
        if (surface == null) return;
        unowned X.Display display = ((Gdk.X11.Display) surface.display).get_xdisplay ();
        X.Window child;
        display.translate_coordinates (xid (surface), display.default_root_window (), 0, 0, out x, out y, out child);
#endif
    }

    public void move_to (int x, int y) {
#if X11
        var surface = get_surface () as Gdk.X11.Surface;
        if (surface == null) return;
        ((Gdk.X11.Display) surface.display).get_xdisplay ().move_window (xid (surface), x, y);
#endif
    }
}
