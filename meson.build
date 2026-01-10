project('lazycat-terminal', 'vala', 'c',
  version: '0.1.0',
  meson_version: '>= 0.50.0',
)

gnome = import('gnome')

cc = meson.get_compiler('c')

# Include directory for font_utils.h
inc_dir = include_directories('src')

# C-only dependencies for font_utils
fontconfig_dep = dependency('fontconfig')
glib_dep = dependency('glib-2.0')

# Build font_utils as a static library
font_utils_lib = static_library('font_utils',
  'src/font_utils.c',
  include_directories: inc_dir,
  dependencies: [fontconfig_dep, glib_dep],
)

# Vala dependencies
vala_deps = [
  dependency('gtk4'),
  dependency('vte-2.91-gtk4'),
  meson.get_compiler('vala').find_library('posix'),
  cc.find_library('m', required: true),
]

vala_sources = files(
  'src/main.vala',
  'src/shadow_window.vala',
  'src/window.vala',
  'src/tab_bar.vala',
  'src/terminal_tab.vala',
  'src/confirm_dialog.vala',
)

executable('lazycat-terminal',
  vala_sources,
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src', '--pkg=font_utils'],
  include_directories: inc_dir,
  link_with: font_utils_lib,
  dependencies: vala_deps,
  install: true,
)
