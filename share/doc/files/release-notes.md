# Files Release Notes

All notable changes are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/); this project uses
[semantic versioning](https://semver.org/). The `[Unreleased]` section
accumulates changes; `tools/bin/release_check` and the `/release` process move
it under a dated version heading when a release is cut.

## [Unreleased]

### Added
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
