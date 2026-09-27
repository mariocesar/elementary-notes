# Pad

The simplest note taking app: one sticky note on your desktop, saved as you type. GTK 4 and Vala. Formerly elementary-notes.

<p align="center">
  <img src="screenshots/screenshot.png" width="460" alt="A yellow note window with a Markdown list, headings and a quote">
</p>

- One note, one Markdown file, with Markdown highlighting and smart indentation.
- Saved half a second after you stop typing, at least every five seconds while you keep going, and when you switch away or close it.
- Opens as a floating note on GNOME, elementary and niri, at the size you last left it.
- Offline, no accounts, no tracking.

The note lives in `~/.local/share/pad/Notes.md`. To keep it somewhere else, like a synced folder:

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
