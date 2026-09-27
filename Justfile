run:
    -pkill -x pad
    meson compile -C build
    meson devenv -C build pad

test:
    meson test -C build

# Retake the README screenshot from screenshots/samples. niri only; opens two Pad windows for a few
# seconds, so leave the desktop alone until it is done.
screenshots:
    #!/usr/bin/env bash
    set -euo pipefail
    meson compile -C build
    pkill -x pad || true
    tmp=$(mktemp -d)
    trap 'pkill -x pad || true; rm -rf "$tmp"' EXIT
    export GSETTINGS_SCHEMA_DIR=build/data GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME=$tmp/config XDG_DATA_HOME=$tmp/data
    mkdir -p "$tmp/data/pad"
    cp screenshots/samples/Notes.md "$tmp/data/pad/"
    cp screenshots/samples/pancakes.md "$tmp/"
    gsettings set io.github.mariocesar.Pad window-sizes "[('$tmp/data/pad/Notes.md', 440, 470), ('$tmp/pancakes.md', 380, 320)]"
    wid() { niri msg --json windows | jq ".[] | select(.app_id == \"io.github.mariocesar.Pad\" and .title == \"$1\") | .id"; }
    # Each window is shot while focused, so neither looks inactive.
    shot() {
        id=$(wid "$1")
        niri msg action focus-window --id "$id"
        sleep 1
        niri msg action screenshot-window --id "$id" --path "$2"
        timeout 10 sh -c 'until [ -s "$0" ]; do sleep 0.2; done' "$2"
    }
    # Trims the transparent margin and GTK's 1px frame, then rounds the corners and adds a soft shadow.
    frame() {
        magick "$1" -trim +repage -shave 2x2 -alpha set \
            \( +clone -alpha transparent -fill white -draw "roundrectangle 0,0 %[fx:w-1],%[fx:h-1] 24,24" \) \
            -compose DstIn -composite -compose Over \
            \( +clone -background '#1d2a3a' -shadow 28x28+0+18 \) +swap -background none -layers merge +repage "$2"
    }
    build/src/pad &
    sleep 1.5
    build/src/pad "$tmp/pancakes.md"
    sleep 1
    shot Notes.md "$tmp/notes.png"
    shot pancakes.md "$tmp/pancakes.png"
    frame "$tmp/notes.png" "$tmp/notes-framed.png"
    frame "$tmp/pancakes.png" "$tmp/pancakes-framed.png"
    magick -size 1800x1240 -define gradient:angle=135 gradient:'#e4ebf4'-'#b9c8dc' \
        "$tmp/notes-framed.png" -geometry +110+70 -composite \
        "$tmp/pancakes-framed.png" -geometry +880+500 -composite \
        -depth 8 screenshots/pad.png
    oxipng -q -o 4 --strip safe screenshots/pad.png

# Install into ~/.local: pad on the PATH, desktop entry, icon, metadata and settings schema.
install:
    test -d build-local || meson setup build-local --prefix=$HOME/.local -Dbuildtype=release
    meson install -C build-local
