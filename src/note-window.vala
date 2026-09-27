public class Notes.NoteWindow : Gtk.ApplicationWindow {
    unowned Application app;
    GtkSource.View view;
    GtkSource.Buffer buffer;
    uint save_source;

    public NoteWindow (Application app) {
        // Fixed size like a paper note; niri also opens fixed-size windows floating.
        Object (application: app, title: "Note", resizable: false, default_width: 460, default_height: 500);
        this.app = app;
        add_css_class ("note");
        titlebar = new Gtk.HeaderBar () { decoration_layout = "close:" };

        buffer = new GtkSource.Buffer.with_language (GtkSource.LanguageManager.get_default ().get_language ("markdown")) {
            style_scheme = GtkSource.StyleSchemeManager.get_default ().get_scheme ("solarized-light"),
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
            if (!((string) contents).validate ()) throw new ConvertError.ILLEGAL_SEQUENCE ("not UTF-8 text");
            // Loading is not an edit that undo can take back.
            buffer.begin_irreversible_action ();
            buffer.text = (string) contents;
            buffer.end_irreversible_action ();
        } catch (IOError.NOT_FOUND e) {
            // A new note; the file is created on the first save.
        } catch (Error e) {
            // Never overwrite a note that could not be read.
            warning ("Reading %s: %s", app.file.get_path (), e.message);
            view.editable = false;
            title = "Note (read only)";
        }
    }

    void save () {
        try {
            try {
                app.file.get_parent ().make_directory_with_parents ();
            } catch (IOError.EXISTS e) {}
            app.file.replace_contents (buffer.text.data, null, false, FileCreateFlags.NONE, null);
            title = "Note";
        } catch (Error e) {
            warning ("Saving %s: %s", app.file.get_path (), e.message);
            title = "Note (not saved)";
        }
    }

    public override bool close_request () {
        if (save_source != 0) {
            Source.remove (save_source);
            save_source = 0;
            save ();
        }
        return base.close_request ();
    }
}
