// Loading and saving the note, in a temporary XDG_DATA_HOME.
using Notes;

Notes.Application app;

GtkSource.View open_note (out NoteWindow win) {
    win = new NoteWindow (app);
    return (GtkSource.View) ((Gtk.ScrolledWindow) win.child).child;
}

// close () ignores a window that was never shown, so run its close handler directly.
void close_note (NoteWindow win) {
    bool stop;
    Signal.emit_by_name (win, "close-request", out stop);
    win.destroy ();
}

void write_note (string text) {
    try {
        app.file.get_parent ().make_directory_with_parents ();
    } catch (IOError.EXISTS e) {
    } catch (Error e) {
        error (e.message);
    }
    try {
        app.file.replace_contents (text.data, null, false, FileCreateFlags.NONE, null);
    } catch (Error e) {
        error (e.message);
    }
}

string read_note () {
    uint8[] contents;
    try {
        app.file.load_contents (null, out contents, null);
    } catch (Error e) {
        error (e.message);
    }
    return (string) contents;
}

void add_window_tests () {
    Test.add_func ("/note/loads-file", () => {
        write_note ("# Groceries\n- milk\n");
        NoteWindow win;
        var view = open_note (out win);
        assert_cmpstr (view.buffer.text, CompareOperator.EQ, "# Groceries\n- milk\n");
        assert_false (((GtkSource.Buffer) view.buffer).can_undo);
        win.destroy ();
    });

    Test.add_func ("/note/saves-on-close", () => {
        write_note ("one\n");
        NoteWindow win;
        var view = open_note (out win);
        Gtk.TextIter end;
        view.buffer.get_end_iter (out end);
        view.buffer.insert (ref end, "two\n", -1);
        close_note (win);
        assert_cmpstr (read_note (), CompareOperator.EQ, "one\ntwo\n");
    });

    Test.add_func ("/note/creates-missing-folder", () => {
        try {
            app.file.delete ();
            app.file.get_parent ().delete ();
        } catch (Error e) {
            error (e.message);
        }
        NoteWindow win;
        var view = open_note (out win);
        assert_cmpstr (view.buffer.text, CompareOperator.EQ, "");
        view.buffer.text = "first note";
        close_note (win);
        assert_cmpstr (read_note (), CompareOperator.EQ, "first note");
    });

    Test.add_func ("/note/keeps-unreadable-file", () => {
        write_note ("bad \xff bytes");
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Reading *not UTF-8 text");
        NoteWindow win;
        var view = open_note (out win);
        Test.assert_expected_messages ();
        assert_false (view.editable);
        close_note (win);
        assert_cmpstr (read_note (), CompareOperator.EQ, "bad \xff bytes");
    });
}

int main (string[] args) {
    // Before anything reads and caches the user data dir.
    try {
        Environment.set_variable ("XDG_DATA_HOME", DirUtils.make_tmp ("notes-test-XXXXXX"), true);
    } catch (Error e) {
        error (e.message);
    }
    if (!Gtk.init_check ()) {
        print ("1..0 # SKIP no display\n");
        return 0;
    }
    Test.init (ref args);
    app = new Notes.Application ();
    app.flags |= ApplicationFlags.NON_UNIQUE;
    try {
        app.register ();
    } catch (Error e) {
        error ("register: %s", e.message);
    }
    add_window_tests ();
    return Test.run ();
}
