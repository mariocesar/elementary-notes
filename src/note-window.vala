public class Notes.NoteWindow : Gtk.ApplicationWindow {
    unowned Application app;
    GtkSource.Buffer buffer;
    uint save_source;

    public NoteWindow (Application app) {
        Object (application: app, title: "Note");
        this.app = app;
        add_css_class ("note");
        titlebar = new Gtk.HeaderBar () { decoration_layout = "close:" };
        default_width = app.settings.get_int ("window-width");
        default_height = app.settings.get_int ("window-height");

        buffer = new GtkSource.Buffer.with_language (GtkSource.LanguageManager.get_default ().get_language ("markdown")) {
            style_scheme = GtkSource.StyleSchemeManager.get_default ().get_scheme ("solarized-light"),
        };
        var view = new GtkSource.View.with_buffer (buffer) {
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
            if (save_source != 0) Source.remove (save_source);
            save_source = Timeout.add (500, () => {
                save_source = 0;
                save ();
                return Source.REMOVE;
            });
        });
    }

    void load () {
        try {
            uint8[] contents;
            app.file.load_contents (null, out contents, null);
            // Loading is not an edit that undo can take back.
            buffer.begin_irreversible_action ();
            buffer.text = (string) contents;
            buffer.end_irreversible_action ();
        } catch (IOError.NOT_FOUND e) {
            // A new note; the file is created on the first save.
        } catch (Error e) {
            warning ("Reading %s: %s", app.file.get_path (), e.message);
        }
    }

    void save () {
        try {
            try {
                app.file.get_parent ().make_directory_with_parents ();
            } catch (IOError.EXISTS e) {}
            app.file.replace_contents (buffer.text.data, null, false, FileCreateFlags.NONE, null);
        } catch (Error e) {
            warning ("Saving %s: %s", app.file.get_path (), e.message);
        }
    }

    public override bool close_request () {
        if (save_source != 0) {
            Source.remove (save_source);
            save_source = 0;
            save ();
        }
        int width, height;
        get_default_size (out width, out height);
        app.settings.set_int ("window-width", width);
        app.settings.set_int ("window-height", height);
        return base.close_request ();
    }
}
