# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`files` is an Ada 2022 desktop file manager. Core logic (~38K LOC in `src/`) is platform-agnostic; rendering uses Vulkan + GLFW + `textrender`. Linux is the only production-validated platform.

## Build, test, verify

Built with Alire (`alr`), which wraps GNAT and the `.gpr` project files.
Use Alire GNAT 15 only. The development, release, tests, nested tests, and tools
manifests pin `gnat_native = "=15.2.1"`. Validate with
`alr exec -- gnatls --version`.
Do not run plain system `gnat*`, `gnatmake`, `gnatls`, `gnatprove`, or
`gprbuild` in this workspace; use `alr exec -- ...` for compiler and builder
commands.

- `alr build` — compile the main app. Style is checked at compile time, so a clean build also passes style.
- `alr test` — run the AUnit suite (lives in `tests/`, its own `alire.toml`/`.gpr`).
- check_all — `tools/files_check_all.gpr` builds the `check_all` utility for file-format validation and full GNAT compiles.
- `bin/files [PATH...]` — run the built app (defaults to home dir). `--runtime-smoke` / `--live-smoke` for headless/live validation (needs Vulkan + display).

Verify non-trivial changes with the full chain: `alr build` → `alr test` → check_all. Or run `/verify-deep`.

## Dependencies need sibling checkouts

`alire.toml` pins `i18n`, `textrender`, `zlib`, and `guikit` to relative
paths (`../i18n`, etc.), not published crates. The tooling crate pins
`project_tools` under `tools/alire.toml`; the runtime crate should not depend
on it. Builds fail unless those sibling directories exist next to this repo.

## Code style (enforced by the compiler — not just convention)

These come from `config/files_config.gpr` and will **fail the build** if violated:

- 3-space indentation (`-gnaty3`)
- 120-character max line length (`-gnatyM120`) — a hard limit
- Full GNAT style checks (`-gnatya`, casing, layout, spacing) and full warnings (`-gnatwa`)
- UTF-8 source encoding (`-gnatW8`), Ada 2022

## Platform-specific sources

Source dirs are selected by OS: `src/platform/{windows,macos,unsupported}`. Only Linux is validated; treat Windows/macOS bindings as present-but-unverified.

## Rendering and UI components

Two-phase render, each phase a subunit of `Files.Rendering`: `Files.Model` → `Build_Snapshot` (an immutable `View_Snapshot`, in `files-rendering-build_snapshot.adb`) → `Build_Frame_Commands` (a `Frame_Commands` draw list, in `files-rendering-build_frame_commands.adb`) → Vulkan. Input flows back the other way: `Files.Events` (translate to an `Input_Action`) → `Files.Interaction` (dispatch) → `Files.Controller` (apply to the model). Keep `files-rendering.adb` itself from regrowing — move any new large subprogram body into its own subunit.

Reusable UI pieces are black-box components in `../guikit` (`Guikit.Command_Palette`, `Settings_Panel`, `Segmented`, `Item_Grid`). files owns the domain (selection, rename, icon assets, localization) and maps it to each component's neutral inputs. **Whether a component is stateful fixes how it integrates — do not re-decide per component:**

- **Stateless render helpers** (`Segmented`, `Item_Grid`) are called from inside `Build_Frame_Commands`, driven by the snapshot. Prefer this.
- **Stateful overlays** (`Command_Palette`, `Settings_Panel` — they hold query/scroll/focus state across frames) cannot pass through the immutable snapshot: their instance lives in the `Window_Model`, and they render at the window layer (`files-application-windows.adb`), merged into the cached frame via `Append_Overlay`.

## Localization

`share/files.catalog` and `share/locales/files-*.catalog` are plain-text `key=value` catalogs (default locale at top, keys namespaced like `en.command.view.small`). Generated/converted by the `cldr_to_catalog` tool. Settings use a separate custom format documented in `share/doc/files/settings-format.md`.

## Conventions

- Commits follow conventional-commits style (`feat:`, `fix:`, `refactor:`, etc.).
- For non-trivial changes, propose a short plan and wait for approval before editing.
