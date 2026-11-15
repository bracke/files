# Files Settings Format

The settings file is a plain text file with named sections and `key = value`
entries. Missing settings use built-in defaults. A value may be quoted
(`"..."`); quoting keeps a value that contains `=`, starts with `#`, or ends
in a blank intact. Sections are written in the order below; the last four are
written only when they hold something.

## `[settings]`

Global options. Booleans are `true` or `false`. A key that is absent takes
its default; the keys marked *omitted when default* are written only after
they change.

| Key | Values | Default |
|---|---|---|
| `default_view_mode` | `small_icons` (or `small`), `large_icons` (or `large`), `details` | `small_icons` |
| `show_hidden_files` | boolean | `false` |
| `show_file_extensions` | boolean | `true` |
| `show_used_space` | boolean: the status bar shows used space rather than free space | `false` |
| `show_space_bar` | boolean: a used/free bar instead, taking precedence over `show_used_space` | `false` |
| `sort_field` | `name`, `filetype`, `size`, `created`, `modified` | `name` |
| `sort_ascending` | boolean | `true` |
| `theme` | `dark`, `light`, `high_contrast` | `dark` |
| `icon_theme` | `"files-basic"`, `"files-high-contrast"` (quoted) | `"files-basic"` |
| `font_pixel_size` | whole number, 10 to 32 | `16` |
| `info_pane_open` | boolean: the info pane is open at start | `false` |
| `use_system_default_opener` | boolean: without a matching open action, use the host's default opener | `true` |
| `group_by` | `none`, `type`, `modified`, `size`, `label` | `none` |
| `detail_column_order` | comma-separated permutation of `name`, `modified`, `size`, `filetype` (or `type`), `created`, `permissions`, `name` first; *omitted when default* | `name,modified,size,filetype,created,permissions` |
| `detail_column_<column>` | boolean, for `modified`, `size`, `filetype`, `created`, `permissions` | `true` for the first three, `false` for `created` and `permissions` |
| `detail_column_width_<column>` | width in reference pixels (scaled with the line height), `0` for the proportional default; *omitted when default* | `0` |
| `window_width`, `window_height` | pixels, clamped to 200 to 16384, `0` for the platform default; *omitted when default* | `0` |

## `[filetypes]`

Maps filename extensions to filetype identifiers, one `extension = filetype`
per line.

## `[icons]`

Maps filetype identifiers to icon identifiers, one `filetype = icon` per line.

## `[open-actions]`

Maps filetypes, and modifier-specific filetype tokens, to an executable plus
an argument vector.

Open actions are argument vectors, not shell command strings. Shell execution
is used only when the action explicitly opts in (`shell:`).

Supported placeholders:

1. `{path}` expands to the full selected file path.
2. `{parent}` expands to the parent directory.
3. `{name}` expands to the filename with extension.
4. `{stem}` expands to the filename without extension.
5. `{extension}` expands to the extension without the leading dot, as the
   name spells it.

Placeholders must occupy a whole argument. Embedded placeholder interpolation
is rejected before execution.

Modifier-specific open-action tokens normalize modifiers in this order:

1. `shift`
2. `control`
3. `alt`
4. `meta`

For example, `text/plain+control+alt` is checked before falling back to
`text/plain`.

## `[bookmarks]`

The favorites, in the order they were starred, one
`bookmark = "<path>"` per line. A path holding a NUL or a line break cannot
be stored. An older file may write the bare path as the key; it still loads.

## `[labels]`

Color labels, one `label = "<color>|<path>"` per line, where `<color>` is one
of `red`, `orange`, `yellow`, `green`, `blue`, `purple`, `gray`. The path is
everything after the first `|`, so it may itself contain `|` or `=`. An entry
with an unknown color is skipped, so one bad tag never blocks loading.

## `[recent]`

Recently opened items and folders, most recent first, one
`recent = "<path>"` per line, at most 50 entries.

## `[shortcuts]`

Keyboard-shortcut overrides. Each entry is written as
`shortcut = "<command>|<combo>"`, where `<command>` is a stable command
identifier and `<combo>` is the shortcut text (modifiers then key, joined by
`+`, e.g. `control+shift+1`). An empty `<combo>` records an explicit unbind
that suppresses the command's built-in default. Overrides for unknown command
identifiers are ignored, so a stale file never blocks startup.
