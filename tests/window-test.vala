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
    wait_for_save (win);
}

void wait_for_save (NoteWindow win) {
    while (win.saving) MainContext.default ().iteration (true);
}

// Runs the main loop, so save timeouts can fire.
void run_for (uint ms) {
    var loop = new MainLoop ();
    Timeout.add (ms, () => {
        loop.quit ();
        return Source.REMOVE;
    });
    loop.run ();
}

void type_text (GtkSource.View view, string text) {
    Gtk.TextIter end;
    view.buffer.get_end_iter (out end);
    view.buffer.insert (ref end, text, -1);
}

uint64 inode () {
    try {
        return app.file.query_info ("unix::inode", FileQueryInfoFlags.NONE).get_attribute_uint64 ("unix::inode");
    } catch (Error e) {
        error (e.message);
    }
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
        type_text (view, "two\n");
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

    Test.add_func ("/note/custom-file", () => {
        app.settings.set_string ("note-file", "~/Sync/Todo.md");
        assert_cmpstr (app.file.get_path (), CompareOperator.EQ, Path.build_filename (Environment.get_home_dir (), "Sync", "Todo.md"));
        write_note ("custom\n");
        NoteWindow win;
        var view = open_note (out win);
        assert_cmpstr (view.buffer.text, CompareOperator.EQ, "custom\n");
        win.destroy ();
        app.settings.reset ("note-file");
    });

    Test.add_func ("/note/setting-changed-while-open", () => {
        write_note ("first\n");
        NoteWindow win;
        var view = open_note (out win);
        var first = app.file;
        app.settings.set_string ("note-file", "~/Other.md");
        view.buffer.text = "edited\n";
        close_note (win);
        assert_false (app.file.query_exists ());
        app.settings.reset ("note-file");
        assert_true (app.file.equal (first));
        assert_cmpstr (read_note (), CompareOperator.EQ, "edited\n");
    });

    Test.add_func ("/save/after-a-pause", () => {
        write_note ("start\n");
        NoteWindow win;
        var view = open_note (out win);
        type_text (view, "a");
        run_for (300);
        assert_cmpstr (read_note (), CompareOperator.EQ, "start\n");
        run_for (400);
        wait_for_save (win);
        assert_cmpstr (read_note (), CompareOperator.EQ, "start\na");
        close_note (win);
    });

    Test.add_func ("/save/while-typing", () => {
        write_note ("");
        NoteWindow win;
        var view = open_note (out win);
        // Never pauses long enough, but the oldest edit still gets saved within five seconds.
        for (var i = 0; i < 23; i++) {
            type_text (view, "x");
            run_for (250);
        }
        wait_for_save (win);
        assert_true (read_note ().length >= 20);
        close_note (win);
        assert_cmpstr (read_note (), CompareOperator.EQ, string.nfill (23, 'x'));
    });

    Test.add_func ("/save/skips-unchanged", () => {
        write_note ("same\n");
        var before = inode ();
        NoteWindow win;
        var view = open_note (out win);
        type_text (view, "typo");
        view.buffer.undo ();
        run_for (700);
        close_note (win);
        assert_true (inode () == before);
    });

    Test.add_func ("/save/edit-during-write", () => {
        write_note ("");
        NoteWindow win;
        var view = open_note (out win);
        type_text (view, "a");
        while (!win.saving) MainContext.default ().iteration (true);
        type_text (view, "b");
        close_note (win);
        assert_cmpstr (read_note (), CompareOperator.EQ, "ab");
    });
}

int main (string[] args) {
    // Before anything reads and caches the home and user data dirs.
    try {
        var home = DirUtils.make_tmp ("notes-test-XXXXXX");
        Environment.set_variable ("HOME", home, true);
        Environment.set_variable ("XDG_DATA_HOME", Path.build_filename (home, "data"), true);
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
