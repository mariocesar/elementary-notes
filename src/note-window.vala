public class Pad.NoteWindow : Gtk.ApplicationWindow {
    // Edits are saved once typing pauses, and at least this often while it goes on.
    const int64 SAVE_PAUSE = 500 * TimeSpan.MILLISECOND;
    const int64 SAVE_MAX_WAIT = 5 * TimeSpan.SECOND;

    public File file { get; private set; }
    // Shown as the window title.
    string file_name;
    GtkSource.View view;
    GtkSource.Buffer buffer;
    uint save_source;
    // Monotonic times of the first and last edit waiting for save_source.
    int64 first_edit;
    int64 last_edit;
    // Whether a write is running; the file is never written twice at once.
    public bool saving { get; private set; }
    bool save_again;
    // Held from closing until the last write is done, so the app doesn't quit mid-write.
    GLib.Application? held;

    public NoteWindow (Application app, File file) {
        // Opens at a fixed size so niri floats it, then becomes resizable once shown.
        Object (application: app, title: file.get_basename (), resizable: false);
        int width, height;
        app.window_size (file, out width, out height);
        set_default_size (width, height);
        map.connect_after (() => Idle.add (() => {
            resizable = true;
            return Source.REMOVE;
        }));
        this.file = file;
        file_name = file.get_basename ();
        add_css_class ("note");
        titlebar = new Gtk.HeaderBar () { decoration_layout = "close:" };

        // Highlighting follows the file name; notes, plain text and unknown files read as Markdown.
        var languages = GtkSource.LanguageManager.get_default ();
        var language = languages.guess_language (file_name, null) ?? languages.get_language ("markdown");
        buffer = new GtkSource.Buffer.with_language (language) {
            style_scheme = GtkSource.StyleSchemeManager.get_default ().get_scheme ("pad"),
        };
        view = new GtkSource.View.with_buffer (buffer) {
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
        child = new Gtk.ScrolledWindow () { child = view, hexpand = true, vexpand = true };

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
            } catch (Error e) {
                // Kept modified: the next edit or closing tries again.
                warning ("Saving %s: %s", file.get_path (), e.message);
                title = file_name + " (not saved)";
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
        if (get_mapped () && !maximized && !fullscreened) ((Application) application).remember_size (file, get_width (), get_height ());
        if (held == null) {
            held = application;
            held.hold ();
        }
        save.begin ();
        return base.close_request ();
    }
}
