# Files Release Notes

All notable changes are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/); this project uses
[semantic versioning](https://semver.org/). The `[Unreleased]` section
accumulates changes; `tools/bin/release_check` and the `/release` process move
it under a dated version heading when a release is cut.

## [Unreleased]

### Added
- Empty Trash: permanently clear every item in the trash in one action.
- Rubber-band (marquee) selection: drag a rectangle over empty space to select
  items; hold Ctrl/Shift to add to the current selection.
- Copy Path (Ctrl+Shift+C) copies the selected items' full paths to the system
  clipboard, and Open Containing Folder reveals a search result in its own
  directory.
- More keyboard shortcuts: New Folder (Ctrl+Shift+N), Toggle Favorite (Ctrl+B),
  Recursive Search (Ctrl+Shift+S), F5 to refresh, and Backspace to delete.
- Favorites: star any file or folder (Toggle Favorite) and reach it from the
  Favorites section of the side panel, marked with a ★. This replaces and
  generalizes the old folder-only bookmarks. Favorited items show a ★ in the
  grid, and the path bar has a star toggle (filled when the current folder is a
  favorite, empty otherwise) that adds/removes it on click.
- Multi-level undo and redo (Ctrl+Z / Ctrl+Shift+Z) — undo is no longer limited
  to a single step.
- Type-to-select: type a file's name in the grid to jump to it.
- Invert Selection (Ctrl+I) and Deselect All (Ctrl+Shift+A).
- A toolbar Up button (Alt+↑) to go to the parent folder.
- Drag-and-drop now uses the same conflict resolution (Replace/Skip/Rename) and
  progress/cancel as clipboard paste instead of silently renaming.
- Editable ownership (chown) in the info pane, alongside the permissions grid.
- Details columns can be reordered by dragging their headers.
- The new commands (Copy/Move to…, create link, open terminal) are on the
  right-click menu, and a details-header menu toggles columns and grouping.
- Copy to… / Move to…: pick a destination folder from the tree sidebar and copy
  or move the selection there, with the same conflict handling and progress as
  paste.
- Paste conflict resolution: pasting over an existing name prompts Replace / Skip
  / Rename (with Apply to all) instead of silently renaming, and long copies/
  moves show a progress bar with Cancel.
- Clickable breadcrumb path and a collapsible folder-tree sidebar.
- Details view: choose which columns to show (incl. new Created and Permissions
  columns), drag column separators to resize, and group items by type, date, or
  size.
- Editable permissions: a rwx grid in the info pane applies chmod (with undo);
  the info pane also shows a directory's recursive size.
- Bottom bar shows free disk space and a selection summary (count + total size).
- Open Terminal Here, and Create Symbolic/Hard Link for the selection.
- UI strings are now fully translated in ten locales (da, de, es, fi, fr, it, nb,
  nl, pt, sv).
- Synchronized multi-cursor rename: select multiple items and rename them all at
  once. Each gets its own inline field and caret; typing/backspace/arrows apply
  to every caret while a mouse click moves just one; Enter commits best-effort.
- Headless GPU display-layer test gate: `bin/files --live-smoke` renders the
  full GLFW + Vulkan path, reads the framebuffer back, and structurally analyses
  it (not-blank, populated bands, meaningful ink), with a PASS/FAIL/SKIP verdict
  and exit codes (0/1/77). CI runs it on Linux under Xvfb + Mesa lavapipe.
- Light color theme, selectable alongside the default dark and high-contrast.
- Close (×) buttons on every overlay panel (command palette, settings, info
  pane, root selector) that dismiss it like Escape.
- The bottom bar shows the number of hidden (dot-file) elements; clicking it
  toggles Show Hidden Files.
- Undo the most recent rename, move, or move-to-trash.
- Duplicate selected items into uniquely-named copies in the same directory.
- Show Hidden Files toggle command (persists the setting and reloads).
- New Folder: create a directory inline, mirroring create-file.
- Open With: pick an installed application (discovered from `.desktop` entries)
  via the command palette and launch the selection with it.
- View and restore trashed items: open the trash directory and restore the
  selection to its original location (freedesktop `.trashinfo` backends).
- Compress selected items into an archive from the right-click menu —
  "Compress Zip" and "Compress 7z" (built on zlib's `ZIP_Files` /
  `Seven_Zip_Deflate_Files`). The archive is named after the first selected
  item; directories are recursed.
- Extract selected `.zip`/`.7z` archives, each into its own new folder (built on
  zlib's `Extract_Archive_File_To_Directory`).
- Release management: a pin-free `alire.release.toml`, a `release_check`
  readiness tool (built on `project_tools`), and a documented release process.

### Changed
- Theme is chosen with a single selector (dark / light / high-contrast) instead
  of separate toggles; the live-smoke GPU gate also checks UI elements render at
  their layout coordinates.
- The item context menu is grouped with separators; Undo has a Ctrl+Z shortcut.
- UI refinements: larger toolbar icons, borderless disabled toolbar buttons,
  wider (untruncated) context menus, fully-padded tooltips, and tighter
  bottom-bar sort spacing. The main-grid hover highlight is suppressed while the
  context menu is open.
- Adopted `project_tools` in the application and tooling (existence checks,
  recursive delete, text reads); moved general-purpose tool helpers into
  `project_tools`.
- Replaced `check_all`'s brittle exact-string contract layer with robust,
  refactor-tolerant checks.

### Fixed
- Arrow-key navigation no longer reverses under descending sort (Up/Down always
  follow the displayed order).
- Renaming in large-icons view: the edit field spans the cell and the caret
  tracks the text, so names are editable.
- Numerous correctness fixes across the file-system, operations, controller,
  model, settings, events, rendering, Vulkan, fonts, accessibility, and
  platform subsystems (see git history).

## [0.1.0-dev] - 2026-06-24

This development snapshot focuses on a complete, testable Ada file-manager
vertical slice plus advanced feature depth.

### Added
- Startup path normalization and one window model per valid directory.
- Deterministic directory loading, metadata, sorting, filtering, and selection.
- View modes for small icons, large icons, and details.
- Central command registry with toolbar, bottom-bar, keyboard, and palette routes.
- Settings parsing, editing, saving, reset, and open-action lookup.
- Trash, permanent delete, rename, create-file, refresh, recursive search, and
  native drop-event queued drop-import operations.
- Vulkan rendering with textrender text, icon assets, live smoke diagnostics,
  and framebuffer readback hashing.
- Accessibility bridge export, high-contrast icon profile, and localized UI text.
- Desktop packaging metadata, AppStream metadata, application icon, and manifest.
- AUnit model, command, filesystem, rendering, runtime, and packaging coverage.

### Known limits
- Windows and macOS platform bodies need validation on those operating systems.
