run:
    -pkill -x elementary-note
    meson compile -C build
    meson devenv -C build elementary-notes

test:
    meson test -C build

# Install into ~/.local: elementary-notes on the PATH, desktop entry, icon and metadata.
install:
    test -d build-local || meson setup build-local --prefix=$HOME/.local -Dbuildtype=release
    meson install -C build-local
