#!/bin/sh
# End-to-end CLI test: a real primary instance and forwarded commands, on a private D-Bus session
# and GTK's headless Broadway display so nothing reaches the user's desktop, running Pad or notes.
# Usage: sh cli-test.sh path/to/pad
PAD=$(realpath "$1")
command -v gtk4-broadwayd >/dev/null || { echo "gtk4-broadwayd not found"; exit 77; }
command -v dbus-run-session >/dev/null || { echo "dbus-run-session not found"; exit 77; }

# Re-run inside a private bus with a private runtime directory, so bus-activated services
# don't replace sockets under the user's /run/user/UID.
if [ -z "$PAD_TEST_ISOLATED" ]; then
    runtime=$(mktemp -d)
    chmod 700 "$runtime"
    PAD_TEST_ISOLATED=1 XDG_RUNTIME_DIR=$runtime GIO_USE_VFS=local GDK_DEBUG=no-portals NO_AT_BRIDGE=1 \
        dbus-run-session -- sh "$0" "$@"
    code=$?
    rm -rf "$runtime"
    exit $code
fi
display=:$(( $$ % 60 + 30 ))
gtk4-broadwayd "$display" >/dev/null 2>&1 &
broadway=$!
trap 'kill $primary $broadway 2>/dev/null' EXIT
export GDK_BACKEND=broadway BROADWAY_DISPLAY=$display GTK_A11Y=none
export GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME=$XDG_RUNTIME_DIR/config XDG_DATA_HOME=$XDG_RUNTIME_DIR/data
work=$XDG_RUNTIME_DIR/work
mkdir -p "$work/sub"
cd "$work" || exit 1
sleep 0.5
failed=0

# expect CODE PATTERN ARGS...: an empty PATTERN means the command must print nothing.
expect() {
    code=$1; pattern=$2; shift 2
    out=$("$PAD" "$@" 2>&1); got=$?
    if [ -z "$pattern" ]; then matched=$([ -z "$out" ] && echo y); else matched=$(printf '%s' "$out" | grep -q -- "$pattern" && echo y); fi
    if [ "$got" -ne "$code" ] || [ -z "$matched" ]; then
        echo "FAIL: pad $* -> exit $got, output: $out (wanted exit $code and /$pattern/)"; failed=1
    else
        echo "ok: pad $*"
    fi
}

owned() {
    gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.NameHasOwner io.github.mariocesar.Pad | grep -q true
}

expect 0 "FILE" --help
expect 0 "[0-9]" --version
expect 1 "is a folder" sub
owned && { echo "FAIL: a rejected command left a process behind"; failed=1; }

"$PAD" a.md &
primary=$!
for i in $(seq 50); do owned && break; sleep 0.1; done
owned || { echo "FAIL: primary never registered"; exit 1; }

# Forwarded to the running instance. Which windows open is covered by the window test.
expect 0 "" b.md
expect 0 "" a.md
cd sub && expect 0 "" ../a.md && cd ..
expect 0 "" c.md d.md
expect 0 ""
expect 1 "is a folder" sub
kill -0 $primary 2>/dev/null || { echo "FAIL: the running instance quit"; failed=1; }
[ -e a.md ] && { echo "FAIL: opening a file without typing created it"; failed=1; }
exit $failed
