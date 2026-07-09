# Files Settings Format

The settings file is a plain text file with named sections and `key = value`
entries. Missing settings use built-in defaults.

Core sections:

1. `[settings]` stores global options such as default view mode, hidden-file
   visibility, sort field, sort order, and icon theme.
2. `[filetypes]` maps filename extensions to filetype identifiers.
3. `[icons]` maps filetype identifiers to icon identifiers.
4. `[open-actions]` maps filetypes and modifier-specific filetype tokens to
   executable plus argument-vector actions.

Open actions are argument vectors, not shell command strings. Shell execution
is used only when the action explicitly opts in.

An optional `[shortcuts]` section persists keyboard-shortcut overrides. Each
entry is written as `shortcut = "<command>|<combo>"`, where `<command>` is a
stable command identifier and `<combo>` is the shortcut text (modifiers then
key, joined by `+`, e.g. `control+shift+1`). An empty `<combo>` records an
explicit unbind that suppresses the command's built-in default. Overrides for
unknown command identifiers are ignored, so a stale file never blocks startup.

Supported placeholders:

1. `{path}` expands to the full selected file path.
2. `{parent}` expands to the parent directory.
3. `{name}` expands to the filename with extension.
4. `{stem}` expands to the filename without extension.
5. `{extension}` expands to the extension without the leading dot.

Placeholders must occupy a whole argument. Embedded placeholder interpolation
is rejected before execution.

Modifier-specific open-action tokens normalize modifiers in this order:

1. `shift`
2. `control`
3. `alt`
4. `meta`

For example, `text/plain+control+alt` is checked before falling back to
`text/plain`.

