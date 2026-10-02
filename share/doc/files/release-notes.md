# Files Release Notes

All notable changes are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/); this project uses
[semantic versioning](https://semver.org/). The `[Unreleased]` section
accumulates changes; `tools/bin/release_check` and the `/release` process move
it under a dated version heading when a release is cut.

## [Unreleased]

### Fixed
- Accessibility frames now reach a11y's native provider bootstrap instead of
  being discarded while the provider is waiting for its first root tree.
- Accessibility integration reports the compiled native provider binding, and
  platform documentation reflects Windows' ACL/SID metadata adapter.
- Failed permission restoration after a directory rename rolls back safely or
  retains a private recovery payload, including its original directory mode.
- Cross-filesystem trash verifies source identities and revisions before removal,
  retaining concurrent edits and replacements and rolling back refused copies.
- New files use exclusive creation and refuse dangling symbolic links and collisions.
- Recursive directory traversal releases enumeration buffers before descending,
  allowing deep copies and cleaning staging when the depth limit is exceeded.
- Batch copies and duplicates preserve hard links across selected roots, including
  background transfers and partial Redo retries, while SHA-256 verification refuses
  edited completed copies even when their size and timestamps are preserved.
- Copy execution and Redo reject destinations redirected inside their source
  trees before staging, retaining retryable history instead of recursive copies.
- Read-only directories retain their permissions after copy publication, moves,
  and Undo/Redo; committed moves clean up private read-only source backups.
- Sparse copies and copy-based moves retain holes and trailing logical length.
- Recursive copies and copy-based moves preserve hard-linked symbolic links.
- Trash and replacement Undo retain original restore destinations even when
  sidecars are changed, truncated, or removed.
- Copy-based moves preserve owning users and groups, including symbolic links,
  across repeated Undo and Redo; ownership failures retain the source.
- Recursive copies and cross-filesystem moves preserve hard links within trees.
- Private staging restores owner access and removes inherited default ACLs, so
  restrictive destination templates cannot prevent copies and recovery.
- Staging journals retain root identities captured at creation; cleanup refuses
  replacements, keeps failed records for retry, and guards foreground stages too.
- Helper staging uses write-ahead, per-stage records, so termination cannot hide
  an intended pathname and one torn record cannot block cleanup of other stages.
- Foreground staging owns a managed cleanup journal too; a refused synchronous
  discard is handed to the cleanup helper instead of leaking the temporary tree.
- Cleanup helpers retry durable staging records and remove their own transport,
  so cleanup progresses while the application is otherwise idle. Their retry
  tenure and parent relaunch count are bounded; permanently refused records
  remain durable without keeping an immortal helper process or worker churn.
- Cleanup workers detach through a synchronously reaped launcher, so completing
  during application idleness leaves no child process handle or zombie behind.
- Startup recovery supervises its coordinator and retries recoverable failures
  with capped backoff. If a coordinator cannot launch, its monitor scans in the
  background so startup stays responsive; shutdown interrupts that fallback
  between candidates rather than waiting through its cleanup retry delays.
  A short fallback pass retains unreadable stage records for later retry.
  A normal window close keeps a successful exit status if host I/O prevents
  the recovery monitor from stopping within the shutdown deadline.
- Development-format markers and current transports without a trustworthy
  lease are reported once per process and preserved rather than claimed by a
  second, potentially independent lock. This also includes pre-lease
  directories regardless of age, markerless leases, and malformed published
  markers. Current markers bind the lease file identity, so replacing its
  pathname cannot authorize cleanup of a live job. The desktop also shows an
  error when recovery leaves an unsafe transport in place. Stage cleanup
  rechecks that the held lease still occupies its pathname before removing
  records, and reclassifies a changed claim on its next pass.
- Shutdown waits briefly for the orphan reaper to drain queued helper work;
  an unfinished reaper cannot be reported as stopped. Queue sealing waits for
  all reserved sessions as well as queued work, so a late owner cannot enqueue
  after completion.
- Transport claims distinguish live ownership, grace-period deferral, unsafe
  candidates, and retryable host errors, so recovery retries only useful work.
- Abandoned-transport cleanup acquires an exclusive lease before inspecting
  stages; a live owner's transport cannot be cleaned through the direct helper
  API. Work helpers join a shared lease before reading their request, so an
  orphaned helper still blocks recovery after its parent exits. A helper that
  loses the race to recovery exits without touching the transport. Cleanup
  publishes a durable retiring marker before releasing its exclusive lease
  for final removal, closing the late-helper race while preserving retry.
- Helper shutdown retains stop intent and retries a failed termination request
  until the process exits or a later request succeeds.
- Failed removal of ordinary helper transports is handed to the cleanup worker
  for idle retry instead of being silently forgotten.
- Undo history admission verifies live identities, complete directory revisions,
  and all required reverse and Redo payloads before recording an action. Batch
  growth retains only the exact prefix already verified, so later snapshots
  cannot inherit that trust.
- Restored helper history rejects malformed action shapes, payloads, retry
  records, and completion markers before they can enter the Undo or Redo stacks.
- Cross-filesystem trash restoration uses the same identity-guarded staging;
  cleanup cannot delete an entry substituted at its temporary pathname.
- Copy, restore, and replacement recovery staging is private at creation, so
  files protected by private source directories remain inaccessible to peers.
- Trash and paste-replace Undo verify recorded payload identities and retain
  retryable history when an unrelated entry occupies a backup pathname.
- Copies and copy-based moves preserve pre-read access timestamps, extended
  attributes and POSIX ACLs; metadata failures retain the original source.
- A separate move-commit journal retains Undo after helper result loss even when
  another entry appears at the original source pathname.
- Cross-filesystem moves verify source tree identities and revisions before
  removal, retaining edited or replaced sources and rolling back their copies.
- Permission and ownership Undo/Redo verify filesystem identity before changing
  metadata. POSIX changes use a held descriptor, including for mode-000 files.
- Metadata history captures live previous permission and ownership values;
  permission toggles also use current mode bits instead of cached listings.
- Paste recovers committed copy/move history and replacement backups when helper
  results are missing or unfinished, retaining the original identity snapshots.
- Helper recovery retains identities recorded at publication, so lost result or
  history metadata cannot authorize Undo to delete unrelated replacements.
- Rename and move Undo/Redo verify the owned entry before applying a transition,
  retaining retryable history when a pathname contains a replacement.
- Renaming a dangling symbolic link treats the link itself as the source;
  guarded history can rename it back without following the missing target.
- Rename no-op detection compares pathnames, so distinct hard links or symbolic
  links to one target are still treated as a destination collision.
- Case-only rename checks the link entry's identity without following its target,
  allowing dangling links while refusing a different link to the same file.
- Case-only renames use atomic no-replace moves for the scratch, final, and
  rollback steps, so a newly occupied pathname cannot be overwritten.
- Same-filesystem moves use the entry identity without reading its contents, so
  moving an unreadable file or a directory with unreadable children still works.
- Creating a hard link to an unreadable file now reports success without recording
  unsafe Undo history. Redo checks that it can snapshot the source before
  publishing the link, so a failed Redo can be retried after access is restored.
- Hard-link creation accepts dangling symbolic links as sources and links the
  symbolic-link entry itself on POSIX systems; Undo and Redo preserve that entry.
  Folder and link creation report dangling destination links as collisions.
- Permanent deletion refuses paths containing `.` or `..` components, preventing
  a crafted path from redirecting recursive deletion to a parent directory.
- Settings saves exclusively create their temporary file and atomically replace
  the destination through the host adapter. An occupied `.tmp` pathname is
  skipped, so a symbolic link there cannot redirect and truncate another file.
- New-file and new-folder default naming skips dangling symbolic-link entries
  instead of proposing a name that creation will immediately reject.
- Thumbnail generation writes to an exclusively created, identity-checked cache
  temp file and atomically publishes it. A symbolic link at the deterministic
  cache pathname is replaced without writing through to its target.
- Thumbnail-cache pruning refuses linked cache roots, so cleanup cannot follow
  a replaced cache directory and delete ordinary files from its link target.
- Open With parses desktop-entry `Exec` quoting and escapes as an argument vector,
  retains file-field position, expands standard metadata fields, and rejects
  malformed or unknown field codes instead of launching a broken command. A
  multi-selection launches once per target for `%f`/`%u`, while `%F`/`%U` launch
  once with every target; `%%` is also decoded in executable names.
- Open With now preflights the chosen executable and reports process-launch
  failures instead of claiming every palette selection executed successfully.
- Application discovery skips linked descendants and bounds recursive scanning,
  so symlink cycles or excessively deep XDG trees cannot hang the Open With picker.
- Application discovery applies XDG precedence by desktop-file ID. User-hidden
  entries mask system copies, while distinct applications with the same display
  name remain available in the Open With picker. Relative XDG base-directory
  values are ignored instead of being resolved against the process directory.
- Open With honors desktop-entry `TryExec`, `OnlyShowIn`, and `NotShowIn`, keeping
  unavailable and session-specific applications out of the picker. Visibility
  lists decode escaped separators, reject invalid escapes, and may coexist when
  they contain disjoint desktop names.
- Open With selects localized desktop-entry names and icons using the message
  locale fallback order, and decodes desktop string escapes before parsing Exec.
- Open With rejects desktop entries with invalid booleans, malformed lines or
  group headers, duplicate keys or groups, and localized values without their
  required base keys instead of accepting ambiguous application metadata.
- Copies preserve directory sticky bits while stripping setuid and setgid bits.
- Copy-based moves preserve file, directory, and symbolic link timestamps,
  including subsecond precision, across repeated Undo and Redo transitions.
- Creation Undo verifies filesystem identity and recursive directory revisions
  before removal, refusing replacements and user changes inside copied trees.
  Redo records fresh identity and tree snapshots for its new entries.
- Creation Undo also checks copied regular-file contents, including files inside
  copied directories, with SHA-256 alongside metadata. A same-size edit with
  its modification time restored keeps the file instead of silently deleting
  the user's changes. The copy worker hashes a standalone file as it writes it;
  later Undo verifies the published contents.
- History excludes entries whose filesystem identity could not be established;
  mixed batches retain their verifiable members without hiding older Undo actions.
- Staged writes fail before copying payload data when the destination filesystem
  cannot provide a reliable directory identity, rather than publishing an
  output that recovery cannot verify.
- Job transports also refuse to start when the temporary filesystem cannot
  provide birth-time identities; copyable nonce files cannot identify a
  recreated directory after inode reuse.
- Windows identity tokens use the complete 128-bit file ID so distinct ReFS
  entries cannot collapse to the same truncated 64-bit ID. The Linux
  no-birth-time simulation now lives behind a test-only API; inherited
  environment variables cannot disable identity checks in the application.
- Windows job leases now compare and record the complete 128-bit file ID as
  well. Older lease markers are recognized but cannot authorize cleanup,
  because their truncated IDs cannot prove which ReFS entry held the lease.
- Recursive copies preserve ordinary permission bits, including executable bits,
  before publication; move fallbacks use the same copy behavior.
- Empty Trash purges hidden payloads and their sidecars independently of the
  hidden-file display preference.
- Searches report traversal, match, and content byte limits as incomplete failures
  instead of silently skipping possible matches or reporting no results.
- Failed move fallbacks remove published copies and restore replaced destinations;
  directory source removal commits atomically before recursive cleanup.
- Character input respects operation dialogs, and searches discard outcomes when
  their query, location, or settings have changed.
- Name and content searches report unreadable directories and files as failures,
  preserving the previous listing instead of presenting incomplete results.
- Info panes populate selected file details after keyboard selection and refresh.
- Duplicate and extraction batches retain one Undo entry, including partial
  failures, so another Undo cannot delete an unrelated replacement at an old path.
- Incoming drops cannot replace active operations or unresolved paste conflicts,
  preserving committed changes and their Undo history.
- Info panes cache empty metadata results and defer metadata reads during a
  pending refresh, keeping manual refreshes valid for unsupported file types.
- ZIP and 7z compression preserve directory entries, including nested empty
  folders and selections containing only directories.
- Compression fails when a selected source is missing, cannot be enumerated, or
  would collide with another archive entry, instead of reporting an incomplete
  archive as successful.
- Recent compression writes beside the first selected source; extraction writes
  beside each archive. Both retain Recent and avoid the process working directory.
- Trash, permanent deletion, restore, empty trash, Undo and Redo run in cancellable
  helpers. History checkpoints preserve completed actions and retry progress;
  failure reloads capture the final error before launching their refresh.
- Each window owns its folder size queue and helper. Input or closure in another
  window leaves that scan alone, and refreshes invalidate cached sizes and pending
  measurements so descendant changes are measured again.
- Successful background refreshes clear obsolete directory load errors while
  preserving file operation errors. Failed listings are retried even when the
  directory signature is unchanged.
- Recursive folder size scans run in cancellable helper processes, keeping
  directory enumeration and file metadata reads out of the UI thread.
- Closing one window stops its transfer, operation, refresh and watch helpers
  immediately, even when other windows remain open. Closed windows release native
  resources before further input dispatch instead of waiting for the last window.
- Duplicate from Recent creates each copy beside its source, including selections
  spanning several folders. Helper completion preserves the Recent listing and Undo.
- Undo and Redo finalize their error state before scheduling a directory reload,
  allowing background refreshes to apply in ordinary folders and Recent.
- Partial Redo verifies completed copies, links, moves, and renames before trusting
  their markers, recreating missing creations and keeping refused retries usable.
- Directory change scans, refresh reloads, and native watch registration run in
  helpers, keeping polling, paste completion, cancellation, and window cleanup
  responsive. Stale reads cannot replace a newer view or settings.
- Cross-filesystem moves and trash operations retain the complete destination
  when deleting the source fails partway.
- Replace aborts when trashing the original fails; it never falls back to
  permanent deletion.
- Cross-filesystem restores copy into a staging directory so failed restores
  can be retried without a partial original blocking them.
- Copy and move destinations are published without overwriting a file, folder,
  or symlink that appears after planning; incomplete copies stay in private staging.
- Trash metadata records symlink pathnames, and trash, delete, restore, and Undo
  also handle dangling links without touching their targets.
- Replace preserves a restorable backup even with native trash backends; failed
  rollback keeps its recovery path in Undo and reports the recovery error.
- Partial replacement Undo remembers completed reversals and restores, so retrying
  cannot delete or relocate an original that an earlier attempt restored.
- Publication journal failures do not misreport completed copies or moves, trigger
  another move fallback, or prevent normal completion from recording Undo.
- Live-window paste, drop, duplicate, compress, extract, and recursive searches
  run in helper processes. Cancellation stops stalled helpers after a grace period,
  and closing a window never waits for a worker task. Completed creations retain Undo.
- Content-search matches remain visible when their filenames do not contain the query.
- Development, release, and test manifests use the accessibility crate's current
  name, and release checks enforce dependency constraints and build-action parity.

### Added
- Content search: find files by what's inside them, not just their names. A scope
  chip on the filter bar switches between filtering the current folder by name,
  searching names in subfolders, and searching file contents; a Search Contents
  command does the same.
- Quick Look: press Space to preview the selected item (image or text) in a
  centered overlay.
- Color labels (tags): assign a color label to any item from a swatch picker;
  labeled items show a colored dot in the grid and can be grouped by label.
- Recent files: a Recent view lists recently opened files and folders, with a
  Clear Recent action.
- More keyboard navigation: Home/End jump to the first/last item, PageUp/PageDown
  page the selection, and Ctrl+plus / Ctrl+minus / Ctrl+0 zoom the font.
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
