run:
    -pkill -x pad
    meson compile -C build
    meson devenv -C build pad

test:
    meson test -C build

# Install into ~/.local: pad on the PATH, desktop entry, icon, metadata and settings schema.
install:
    test -d build-local || meson setup build-local --prefix=$HOME/.local -Dbuildtype=release
    meson install -C build-local
