config_vala = configure_file(input: 'config.vala.in', output: 'config.vala', configuration: conf)

app_sources = [files('application.vala', 'note-window.vala'), config_vala, resources]
app_deps = [
  dependency('glib-2.0', version: '>= 2.80'),
  dependency('gio-2.0', version: '>= 2.80'),
  dependency('gtk4', version: '>= 4.20'),
  dependency('gtksourceview-5', version: '>= 5.10'),
]

notes = executable('elementary-notes', 'main.vala', app_sources, dependencies: app_deps, install: true)
