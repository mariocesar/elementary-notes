config_vala = configure_file(input: 'config.vala.in', output: 'config.vala', configuration: conf)

# Everything but main(), shared with the window test.
app_sources = [files('application.vala', 'note-window.vala'), config_vala, resources]
app_deps = [
  dependency('glib-2.0', version: '>= 2.80'),
  dependency('gio-2.0', version: '>= 2.80'),
  dependency('gtk4', version: '>= 4.20'),
  dependency('gtksourceview-5', version: '>= 5.10'),
  meson.get_compiler('vala').find_library('posix'),
]
# Window positions are only readable and settable on X11.
gtk_x11 = dependency('gtk4-x11', required: false)
if gtk_x11.found()
  app_deps += [gtk_x11, dependency('x11')]
  add_project_arguments('-D', 'X11', language: 'vala')
endif

pad = executable('pad', 'main.vala', app_sources, dependencies: app_deps, install: true)
