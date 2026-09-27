# Notes

One sticky note for the desktop, saved as you type. Vala, GTK 4, GtkSourceView 5, Meson.

## Layout

    src/              application and note window
    data/             desktop, metainfo, gschema and gresource templates; CSS, icon
    tests/            window and data tests
    screenshots/      README image

## Verify

    meson setup build
    meson compile -C build
    meson test -C build
    meson devenv -C build elementary-notes

## Conventions

- Vala, GTK 4, GtkSourceView 5, GLib/GIO and Meson only.
- The note is the `note-file` setting, or `$XDG_DATA_HOME/notes/Notes.md` when it is empty. Never overwrite a note that could not be read.
- Commit subjects are plain imperative sentences. Comments and docs stay short.

## Non-goals

- More than one note, sync, accounts.
- Network, telemetry, a database.
