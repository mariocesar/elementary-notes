# Pad

The simplest note taking app: one sticky note on your desktop, saved as you type. GTK 4 and Vala. Formerly elementary-notes.

<p align="center">
  <img src="screenshots/screenshot.png" width="460" alt="A yellow note window with a Markdown list, headings and a quote">
</p>

- Your default note, or any Markdown or text file with `pad README.md`, with Markdown highlighting and smart indentation.
- Saved half a second after you stop typing, at least every five seconds while you keep going, and when you switch away or close it.
- Opens as a floating note on GNOME, elementary and niri, at the size you last left it.
- Offline, no accounts, no tracking.

## Using it

    pad               open the default note
    pad README.md     open README.md, saved as you type
    pad a.md b.md     one window per file

Relative paths work from any folder, and a file that is already open comes to the front instead of opening twice. A file that doesn't exist yet is created when you start typing.

The default note lives in `~/.local/share/pad/Notes.md`. To keep it somewhere else, like a synced folder:

    gsettings set io.github.mariocesar.Pad note-file '~/Dropbox/Notes/Notes.md'

It takes effect the next time Pad opens. `gsettings reset io.github.mariocesar.Pad note-file` goes back to the default.

## Install

You need Meson, Vala, GTK 4.20 or newer and GtkSourceView 5.

    meson setup build
    meson compile -C build
    sudo meson install -C build

Or `just install` to install into `~/.local`.

## Develop

    just run
    just test

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).
