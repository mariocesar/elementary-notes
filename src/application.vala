namespace Pad {
    // Not deprecated in C; only the Vala StyleContext class wrapper is.
    [CCode (cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    extern void add_provider_for_display (Gdk.Display display, Gtk.StyleProvider provider, uint priority);

    public class Application : Gtk.Application {
        public GLib.Settings settings { get; private set; }

        // The note opened without a file: the note-file setting, or Notes.md in the user data folder.
        public File default_file {
            owned get {
                var path = settings.get_string ("note-file");
                if (path == "") return File.new_build_filename (Environment.get_user_data_dir (), "pad", "Notes.md");
                if (path.has_prefix ("~/")) path = Environment.get_home_dir () + path.substring (1);
                return File.new_for_path (path);
            }
        }

        public Application () {
            Object (application_id: Config.APP_ID, flags: ApplicationFlags.HANDLES_COMMAND_LINE, version: Config.VERSION);
            add_main_option (OPTION_REMAINING, 0, 0, OptionArg.FILENAME_ARRAY, "", "[FILE…]");
            set_option_context_summary ("""Open the default note, or the given files.

  pad               open the default note
  pad README.md     open README.md, saved as you type
  pad a.md b.md     one window per file""");
        }

        // Rejects bad paths in the calling process, before anything reaches the running instance.
        public override int handle_local_options (VariantDict options) {
            var paths = options.lookup_value (OPTION_REMAINING, VariantType.BYTESTRING_ARRAY);
            if (paths == null) return -1;
            foreach (var path in paths.get_bytestring_array ()) {
                if (FileUtils.test (path, FileTest.IS_DIR)) {
                    printerr ("pad: %s is a folder; give a file to open\n", path);
                    return 1;
                }
            }
            return -1;
        }

        public override void startup () {
            base.startup ();
            // The note is always yellow paper, so the text stays dark.
            Gtk.Settings.get_default ().gtk_interface_color_scheme = Gtk.InterfaceColorScheme.LIGHT;
            var css = new Gtk.CssProvider ();
            css.load_from_resource (resource_base_path + "/style.css");
            add_provider_for_display (Gdk.Display.get_default (), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            settings = new GLib.Settings (Config.APP_ID);
        }

        public override void activate () {
            window_for (default_file).present ();
        }

        // Runs in the running instance for every invocation. Paths resolve from the caller's folder.
        public override int command_line (ApplicationCommandLine command_line) {
            var paths = command_line.get_options_dict ().lookup_value (OPTION_REMAINING, VariantType.BYTESTRING_ARRAY);
            if (paths == null) {
                activate ();
                return 0;
            }
            foreach (var path in paths.get_bytestring_array ()) window_for (command_line.create_file_for_arg (path)).present ();
            return 0;
        }

        // One window per file: the file's open window, or a new one.
        public NoteWindow window_for (File file) {
            foreach (var window in get_windows ()) {
                if (((NoteWindow) window).file.equal (file)) return (NoteWindow) window;
            }
            return new NoteWindow (this, file);
        }
    }
}
