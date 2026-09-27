datadir = get_option('datadir')

resources = gnome.compile_resources('notes-resources',
  configure_file(input: 'notes.gresource.xml.in', output: 'notes.gresource.xml', configuration: conf),
  source_dir: meson.current_source_dir(),
  c_name: 'notes',
)

desktop_file = configure_file(
  input: 'notes.desktop.in',
  output: app_id + '.desktop',
  configuration: conf,
  install_dir: datadir / 'applications',
)

metainfo_file = configure_file(
  input: 'notes.metainfo.xml.in',
  output: app_id + '.metainfo.xml',
  configuration: conf,
  install_dir: datadir / 'metainfo',
)

install_data('icons/notes.png',
  rename: app_id + '.png',
  install_dir: datadir / 'icons' / 'hicolor' / '128x128' / 'apps',
)
