# Handled by GApplication before GTK starts. Blank displays make a regression fail fast instead of opening a window.
test('cli-version', notes, args: ['--version'], suite: 'app', timeout: 10,
  env: {'WAYLAND_DISPLAY': '', 'DISPLAY': ''})

desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test('desktop-file', desktop_file_validate, args: [desktop_file], suite: 'data')
endif

appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test('metainfo', appstreamcli, args: ['validate', '--no-net', metainfo_file], suite: 'data')
endif

# Needs a display; skips itself without one. Settings stay in memory, never in the user's dconf.
window_test = executable('window-test', 'window-test.vala', app_sources, dependencies: app_deps)
test('window', window_test, suite: 'widget', protocol: 'tap', args: ['--tap'], depends: gschemas,
  env: {'GSETTINGS_SCHEMA_DIR': meson.project_build_root() / 'data', 'GSETTINGS_BACKEND': 'memory'})
