# Files Settings Format

The settings file is a plain text file with named sections and `key = value`
entries. Missing settings use built-in defaults. A value may be quoted
(`"..."`); quoting keeps a value that contains `=`, starts with `#`, or ends
in a blank intact. Sections are written in the order below; the last four are
written only when they hold something.

## Edits from elsewhere

The file may change while files runs: another files process saves it, or
you edit it by hand. Before each save, files reads the file again; when it
changed since files last read or wrote it, every setting files changed in
the meantime keeps files' value and every other one takes the file's (each
scalar, each mapping section, the favorites, the recent items, the labels
and the shortcuts count as one setting each). A file changed into one that
is rejected (below) is not saved over: files says so and keeps its changes
for the session. The same applies at startup to a settings file that cannot
be looked at: files runs on defaults and saves nothing.

## What rejects the file

The file loads whole or not at all. When it is rejected, files reports why at
startup, runs on built-in defaults, and saves nothing: writing the defaults
back would erase the bookmarks, labels and mappings of a file that is only
unreadable to this build, so it is left for you to fix. A file is rejected
when it holds:

- a section header naming no section above (`[colours]`), or a `key = value`
  line before the first header;
- a line that is neither blank, a `#` comment, a `[section]` header, nor a
  `key = value` entry (no `=`);
- in `[settings]`, a key not listed below, or a value the key does not
  accept (`font_pixel_size = 9`, `theme = blue`, `sort_ascending = yes`);
- in `[filetypes]` or `[icons]`, an empty or malformed key or value; in
  `[open-actions]`, an unknown base or modifier, an empty executable, or a
  placeholder embedded in a larger argument;
- a NUL byte anywhere, a line over 64 KiB, more than 4096 entries, or more
  than 1 MiB in all.

Not everything that looks wrong rejects the file: a label with an unknown
color and a shortcut for an unknown command or with a misspelt combo are
skipped (see their sections), and a repeated bookmark or recent entry loads
once.

## `[settings]`

Global options. Booleans are `true` or `false`, in any case (`TRUE` loads). A key
that is absent takes its default; the keys marked *omitted when default* are
written only after they change.

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

Two invalid values do not reject the file: a `detail_column_width_<column>`
that is not a plain decimal number resets that column to its proportional
default (`0`), and a `window_width` or `window_height` that is not one keeps
the platform default. An invalid `detail_column_order` (a column missing,
repeated or unknown) does reject it; a valid one is read with `name` moved to
the front, wherever it was listed.

Older files may carry `high_contrast_theme` and `light_theme` booleans in place
of `theme`. They still load: when `theme` is absent, `high_contrast_theme =
true` selects `high_contrast`, otherwise `light_theme = true` selects `light`;
a `theme` key, wherever it appears, wins over both. They are never written.

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
identifiers are ignored, so a stale file never blocks startup. A combo with a
token files does not know -- a misspelt modifier or key (`control+bogus`,
`control+shfit+1`), an empty token, or more than one key -- is skipped as
well: the command keeps its default binding instead of losing it or taking
whatever the rest of the combo names. Such ignored lines are not kept: the
next save writes the shortcuts as they are in force.
