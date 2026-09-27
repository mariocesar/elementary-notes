# Handled by GApplication before GTK starts. Blank displays make a regression fail fast instead of opening a window.
test('cli-version', pad, args: ['--version'], suite: 'app', timeout: 10,
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

# The same tests on a headless X11 server, where window positions can be tested.
xvfb_run = find_program('xvfb-run', required: false)
if xvfb_run.found()
  test('window-x11', xvfb_run, args: ['-a', window_test, '--tap'], suite: 'widget', protocol: 'tap', depends: gschemas,
    env: {'GSETTINGS_SCHEMA_DIR': meson.project_build_root() / 'data', 'GSETTINGS_BACKEND': 'memory', 'GDK_BACKEND': 'x11'})
endif

# A real primary instance plus forwarded commands, isolated on a private bus and a headless display.
test('cli', find_program('sh'), args: [files('cli-test.sh'), pad], suite: 'app', timeout: 60,
  depends: gschemas, env: {'GSETTINGS_SCHEMA_DIR': meson.project_build_root() / 'data'})
