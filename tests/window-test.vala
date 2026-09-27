// Loading and saving the note, in a temporary XDG_DATA_HOME.

Pad.Application app;

GtkSource.View open_note (out Pad.NoteWindow win) {
    win = new Pad.NoteWindow (app, app.default_file);
    return win.view;
}

// The strip above the text that says why the note couldn't be read or saved.
Gtk.Revealer banner (Pad.NoteWindow win) {
    return (Gtk.Revealer) ((Gtk.Box) win.child).get_first_child ();
}

// close () ignores a window that was never shown, so run its close handler directly.
void close_note (Pad.NoteWindow win) {
    bool stop;
    Signal.emit_by_name (win, "close-request", out stop);
    win.destroy ();
    wait_for_save (win);
}

void wait_for_save (Pad.NoteWindow win) {
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
        return app.default_file.query_info ("unix::inode", FileQueryInfoFlags.NONE).get_attribute_uint64 ("unix::inode");
    } catch (Error e) {
        error (e.message);
    }
}

void write_note (string text) {
    try {
        app.default_file.get_parent ().make_directory_with_parents ();
    } catch (IOError.EXISTS e) {
    } catch (Error e) {
        error (e.message);
    }
    try {
        app.default_file.replace_contents (text.data, null, false, FileCreateFlags.NONE, null);
    } catch (Error e) {
        error (e.message);
    }
}

string read_note () {
    uint8[] contents;
    try {
        app.default_file.load_contents (null, out contents, null);
    } catch (Error e) {
        error (e.message);
    }
    return (string) contents;
}

void add_window_tests () {
    Test.add_func ("/note/loads-file", () => {
        write_note ("# Groceries\n- milk\n");
        Pad.NoteWindow win;
        var view = open_note (out win);
        assert_cmpstr (view.buffer.text, CompareOperator.EQ, "# Groceries\n- milk\n");
        assert_false (((GtkSource.Buffer) view.buffer).can_undo);
        win.destroy ();
    });

    Test.add_func ("/note/pad-style", () => {
        Pad.NoteWindow win;
        var view = open_note (out win);
        assert_cmpstr (((GtkSource.Buffer) view.buffer).style_scheme.id, CompareOperator.EQ, "pad");
        assert_true (view.monospace);
        win.destroy ();
    });

    Test.add_func ("/font/ctrl-plus-and-minus", () => {
        assert_cmpint (app.settings.get_int ("font-size"), CompareOperator.EQ, 11);
        assert_true ("<Control>plus" in app.get_accels_for_action ("app.zoom-in"));
        assert_true ("<Control>minus" in app.get_accels_for_action ("app.zoom-out"));
        app.activate_action ("zoom-in", null);
        assert_cmpint (app.settings.get_int ("font-size"), CompareOperator.EQ, 12);
        app.activate_action ("zoom-out", null);
        app.activate_action ("zoom-out", null);
        assert_cmpint (app.settings.get_int ("font-size"), CompareOperator.EQ, 10);
        // Stays within the setting's range.
        app.settings.set_int ("font-size", 48);
        app.activate_action ("zoom-in", null);
        assert_cmpint (app.settings.get_int ("font-size"), CompareOperator.EQ, 48);
        app.settings.reset ("font-size");
    });

    Test.add_func ("/note/language-from-file-name", () => {
        string[,] cases = {
            { "Notes.md", "markdown" },
            { "deploy.sh", "sh" },
            { "main.vala", "vala" },
            { "todo.txt", "markdown" },
            { "TODO", "markdown" },
        };
        for (var i = 0; i < cases.length[0]; i++) {
            var win = app.window_for (File.new_build_filename (Environment.get_home_dir (), cases[i, 0]));
            var buffer = (GtkSource.Buffer) win.view.buffer;
            assert_cmpstr (buffer.language.id, CompareOperator.EQ, cases[i, 1]);
            win.destroy ();
        }
    });

    Test.add_func ("/note/saves-on-close", () => {
        write_note ("one\n");
        Pad.NoteWindow win;
        var view = open_note (out win);
        type_text (view, "two\n");
        close_note (win);
        assert_cmpstr (read_note (), CompareOperator.EQ, "one\ntwo\n");
    });

    Test.add_func ("/note/creates-missing-folder", () => {
        try {
            app.default_file.delete ();
            app.default_file.get_parent ().delete ();
        } catch (Error e) {
            error (e.message);
        }
        Pad.NoteWindow win;
        var view = open_note (out win);
        assert_cmpstr (view.buffer.text, CompareOperator.EQ, "");
        view.buffer.text = "first note";
        close_note (win);
        assert_cmpstr (read_note (), CompareOperator.EQ, "first note");
    });

    Test.add_func ("/note/keeps-unreadable-file", () => {
        write_note ("bad \xff bytes");
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Reading *not UTF-8 text");
        Pad.NoteWindow win;
        var view = open_note (out win);
        Test.assert_expected_messages ();
        assert_false (view.editable);
        assert_true (banner (win).reveal_child);
        assert_true ("not UTF-8 text" in ((Gtk.Label) banner (win).child).label);
        close_note (win);
        assert_cmpstr (read_note (), CompareOperator.EQ, "bad \xff bytes");
    });

    Test.add_func ("/note/save-failure-shows-banner", () => {
        write_note ("");
        Pad.NoteWindow win;
        var view = open_note (out win);
        assert_false (banner (win).reveal_child);
        // A file where the note's folder was fails the save, even as root.
        var folder = app.default_file.get_parent ().get_path ();
        FileUtils.unlink (app.default_file.get_path ());
        DirUtils.remove (folder);
        try {
            FileUtils.set_contents (folder, "");
        } catch (Error e) {
            error (e.message);
        }
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Saving *");
        type_text (view, "kept");
        run_for (700);
        wait_for_save (win);
        Test.assert_expected_messages ();
        assert_true (banner (win).reveal_child);
        assert_true (((Gtk.Label) banner (win).child).label.has_prefix ("Not saved: "));
        // Once the folder can be made again, the next edit saves everything and hides the banner.
        FileUtils.unlink (folder);
        type_text (view, "!");
        run_for (700);
        wait_for_save (win);
        assert_false (banner (win).reveal_child);
        assert_cmpstr (read_note (), CompareOperator.EQ, "kept!");
        close_note (win);
    });

    Test.add_func ("/note/custom-file", () => {
        app.settings.set_string ("note-file", "~/Sync/Todo.md");
        assert_cmpstr (app.default_file.get_path (), CompareOperator.EQ, Path.build_filename (Environment.get_home_dir (), "Sync", "Todo.md"));
        write_note ("custom\n");
        Pad.NoteWindow win;
        var view = open_note (out win);
        assert_cmpstr (view.buffer.text, CompareOperator.EQ, "custom\n");
        win.destroy ();
        app.settings.reset ("note-file");
    });

    Test.add_func ("/note/setting-changed-while-open", () => {
        write_note ("first\n");
        Pad.NoteWindow win;
        var view = open_note (out win);
        var first = app.default_file;
        app.settings.set_string ("note-file", "~/Other.md");
        view.buffer.text = "edited\n";
        close_note (win);
        assert_false (app.default_file.query_exists ());
        app.settings.reset ("note-file");
        assert_true (app.default_file.equal (first));
        assert_cmpstr (read_note (), CompareOperator.EQ, "edited\n");
    });

    Test.add_func ("/size/per-file", () => {
        var sized = File.new_build_filename (Environment.get_home_dir (), "sized.md");
        var fresh = File.new_build_filename (Environment.get_home_dir (), "fresh.md");
        app.remember_geometry (sized, 620, 380, -1, -1);
        int width, height;
        var win = app.window_for (sized);
        win.get_default_size (out width, out height);
        assert_true (width == 620 && height == 380);
        win.destroy ();
        win = app.window_for (fresh);
        win.get_default_size (out width, out height);
        assert_true (width == 460 && height == 500);
        win.destroy ();
        app.settings.reset ("window-geometry");
    });

    Test.add_func ("/size/most-recent-first", () => {
        for (var i = 0; i < 105; i++) app.remember_geometry (File.new_for_path ("/notes/%d.md".printf (i)), 300 + i, 300, -1, -1);
        app.remember_geometry (File.new_for_path ("/notes/50.md"), 999, 300, -1, -1);
        var sizes = app.settings.get_value ("window-geometry");
        assert_cmpuint ((uint) sizes.n_children (), CompareOperator.EQ, 100);
        string path;
        int width, height, x, y;
        sizes.get_child (0, "(siiii)", out path, out width, out height, out x, out y);
        assert_cmpstr (path, CompareOperator.EQ, "/notes/50.md");
        assert_cmpint (width, CompareOperator.EQ, 999);
        // Past the limit the oldest go first: 0 to 4 are dropped, 5 is the oldest kept.
        app.window_geometry (File.new_for_path ("/notes/4.md"), out width, out height, out x, out y);
        assert_cmpint (width, CompareOperator.EQ, 460);
        app.window_geometry (File.new_for_path ("/notes/5.md"), out width, out height, out x, out y);
        assert_cmpint (width, CompareOperator.EQ, 305);
        app.settings.reset ("window-geometry");
    });

    Test.add_func ("/geometry/unknown-position-keeps-the-last", () => {
        var file = File.new_for_path ("/notes/moved.md");
        app.remember_geometry (file, 400, 300, 150, 120);
        app.remember_geometry (file, 500, 350, -1, -1);
        int width, height, x, y;
        app.window_geometry (file, out width, out height, out x, out y);
        assert_true (width == 500 && height == 350 && x == 150 && y == 120);
        app.settings.reset ("window-geometry");
    });

    // Run under Xvfb by the window-x11 test; skipped on Wayland, where no app knows its position.
    Test.add_func ("/geometry/x11-position", () => {
#if X11
        if (!(Gdk.Display.get_default () is Gdk.X11.Display)) {
            Test.skip ("needs an X11 display");
            return;
        }
        var file = File.new_build_filename (Environment.get_home_dir (), "placed.md");
        app.remember_geometry (file, 400, 300, 150, 120);
        var win = app.window_for (file);
        win.present ();
        run_for (500);
        int x, y;
        win.get_position (out x, out y);
        assert_true (x == 150 && y == 120);
        win.move_to (260, 90);
        run_for (300);
        close_note (win);
        int width, height;
        app.window_geometry (file, out width, out height, out x, out y);
        assert_true (x == 260 && y == 90);
        app.settings.reset ("window-geometry");
#else
        Test.skip ("built without X11");
#endif
    });

    Test.add_func ("/size/symlink-is-the-same-note", () => {
        var target = Path.build_filename (Environment.get_home_dir (), "target.md");
        var link = Path.build_filename (Environment.get_home_dir (), "link.md");
        try {
            FileUtils.set_contents (target, "");
        } catch (Error e) {
            error (e.message);
        }
        FileUtils.symlink (target, link);
        var win = app.window_for (File.new_for_path (target));
        assert_true (app.window_for (File.new_for_path (link)) == win);
        win.destroy ();
        FileUtils.unlink (link);
        FileUtils.unlink (target);
    });

    Test.add_func ("/app/one-window-per-file", () => {
        var a = File.new_build_filename (Environment.get_home_dir (), "a.md");
        var b = File.new_build_filename (Environment.get_home_dir (), "b.md");
        var win_a = app.window_for (a);
        var win_b = app.window_for (b);
        assert_true (win_a != win_b);
        assert_true (app.window_for (File.new_for_path (a.get_path ())) == win_a);
        assert_cmpstr (win_a.title, CompareOperator.EQ, "a.md");
        assert_cmpuint (app.get_windows ().length (), CompareOperator.EQ, 2);
        win_a.destroy ();
        win_b.destroy ();
        assert_false (a.query_exists ());
    });

    Test.add_func ("/save/after-a-pause", () => {
        write_note ("start\n");
        Pad.NoteWindow win;
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
        Pad.NoteWindow win;
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
        Pad.NoteWindow win;
        var view = open_note (out win);
        type_text (view, "typo");
        view.buffer.undo ();
        run_for (700);
        close_note (win);
        assert_true (inode () == before);
    });

    Test.add_func ("/save/edit-during-write", () => {
        write_note ("");
        Pad.NoteWindow win;
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
        var home = DirUtils.make_tmp ("pad-test-XXXXXX");
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
    app = new Pad.Application ();
    app.flags |= ApplicationFlags.NON_UNIQUE;
    try {
        app.register ();
    } catch (Error e) {
        error ("register: %s", e.message);
    }
    add_window_tests ();
    return Test.run ();
}
