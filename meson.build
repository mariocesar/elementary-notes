project('elementary-notes', ['c', 'vala'],
  version: '2.0.0',
  license: 'GPL-3.0-or-later',
  license_files: 'LICENSE',
  meson_version: '>= 1.4',
  default_options: ['warning_level=1', 'buildtype=debugoptimized', 'werror=true'],
)

app_id = 'io.github.mariocesar.Notes'

gnome = import('gnome')

# werror (on by default) makes valac warnings fatal; distro builds pass -Dwerror=false.
# Warnings in valac-generated C are not actionable.
add_project_arguments('-w', language: 'c')

conf = configuration_data()
conf.set('APP_ID', app_id)
conf.set('VERSION', meson.project_version())
conf.set('HOMEPAGE', 'https://github.com/mariocesar/elementary-notes')
conf.set('RESOURCE_PATH', '/' + app_id.replace('.', '/'))

subdir('data')
subdir('src')
subdir('tests')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
