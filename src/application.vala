namespace Notes {
    // Not deprecated in C; only the Vala StyleContext class wrapper is.
    [CCode (cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    extern void add_provider_for_display (Gdk.Display display, Gtk.StyleProvider provider, uint priority);

    public class Application : Gtk.Application {
        public GLib.Settings settings { get; private set; }

        // The one note, a Markdown file: the note-file setting, or Notes.md in the user data folder.
        public File file {
            owned get {
                var path = settings.get_string ("note-file");
                if (path == "") return File.new_build_filename (Environment.get_user_data_dir (), "notes", "Notes.md");
                if (path.has_prefix ("~/")) path = Environment.get_home_dir () + path.substring (1);
                return File.new_for_path (path);
            }
        }

        public Application () {
            Object (application_id: Config.APP_ID, flags: ApplicationFlags.DEFAULT_FLAGS, version: Config.VERSION);
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
            (active_window ?? new NoteWindow (this)).present ();
        }
    }
}
