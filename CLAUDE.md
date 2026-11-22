# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`files` is an Ada 2022 desktop file manager. Core logic (~90K lines in `src/`) is platform-agnostic; rendering uses Vulkan + GLFW + `textrender`. Linux is the only production-validated platform.

## Build, test, verify

Built with Alire (`alr`), which wraps GNAT and the `.gpr` project files.
Use Alire GNAT 15 only. The development, release, tests, and tools
manifests pin `gnat_native = "=15.2.1"`. Validate with
`alr exec -- gnatls --version`.
Do not run plain system `gnat*`, `gnatmake`, `gnatls`, `gnatprove`, or
`gprbuild` in this workspace; use `alr exec -- ...` for compiler and builder
commands.

- `alr build` — compile the main app. Style is checked at compile time, so a clean build also passes style.
- `cd tests && alr test` — run the AUnit suite (it lives in `tests/`, with its own `alire.toml`/`.gpr`, and builds before it runs). `alr test` from the repo root runs *no tests*: with no test action defined there it falls back to a release build and reports success.
- check_all — `tools/files_check_all.gpr` builds the `check_all` utility for file-format validation and full GNAT compiles.
- `bin/files [PATH...]` — run the built app (defaults to home dir). `--runtime-smoke` / `--live-smoke` for headless/live validation (needs Vulkan + display).

Verify non-trivial changes with the full chain: `alr build` → `cd tests && alr test` → check_all. Or run `/verify-deep`.

## Dependencies need sibling checkouts

`alire.toml` pins the sibling runtime crates (`i18n`, `messages`, `hostkit`,
`humanize`, `textrender`, `zlib`, `cryptolib`, `guikit`, and `a11y`) to
relative paths (`../i18n`, etc.; `a11y` lives in `../a11ykit`), not published
crates. The tooling crate pins
`project_tools` under `tools/alire.toml`; the runtime crate should not depend
on it. Builds fail unless those sibling directories exist next to this repo.

## Code style (enforced by the compiler — not just convention)

These come from `config/files_config.gpr` and will **fail the build** if violated:

- 3-space indentation (`-gnaty3`)
- 120-character max line length (`-gnatyM120`) — a hard limit
- Full GNAT style checks (`-gnatya`, casing, layout, spacing) and full warnings (`-gnatwa`)
- UTF-8 source encoding (`-gnatW8`), Ada 2022

## Platform-specific sources

Files uses one source list on every OS; platform-specific services live in the
`hostkit` sibling. Only Linux is validated locally; treat Windows/macOS bindings
as present-but-unverified.

## Rendering and UI components

Two-phase render, each phase a subunit of `Files.Rendering`: `Files.Model` → `Build_Snapshot` (an immutable `View_Snapshot`, built in place by `Build_Snapshot_Into` in `files-rendering-build_snapshot_into.adb`) → `Build_Frame_Commands` (a `Frame_Commands` draw list, in `files-rendering-build_frame_commands.adb`) → Vulkan. Input flows back the other way: `Files.Events` (translate to an `Input_Action`, declared in `Files.Input_Actions`) → `Files.Interaction` (dispatch) → `Files.Controller` (apply to the model). Keep `files-rendering.adb` itself from regrowing — move any new large subprogram body into its own subunit. `Files.Rendering` holds the snapshot and frame types; layout records and their `Calculate_*` functions live in `Files.Rendering.Layouts` (shared with `Hit`, `Events` and the window layer), the metrics they build on (paddings, column widths, saturating arithmetic, text wrapping) in the private child `Files.Rendering.Geometry`, what is shown as text or colour (glyphs, time/size/permission words, info-pane field values, label colours) in the private child `Files.Rendering.Labels`, and the text renderer pool plus per-window glyph cache in `Files.Rendering.Text`. The rule between the first two: anything a drawing and a hit test both resolve against (menu rows, details header and columns, toolbar buttons, the path field's star offset) is `Layouts'`; `Geometry` does not depend on `Layouts`. The window chrome (toolbar and bottom bar, sort dropdown, paddings, default window size) is in `Layouts` too; there is no separate `Files.UI`.

Reusable UI pieces are black-box components in `../guikit` (`Guikit.Command_Palette`, `Settings_Panel`, `Segmented`, `Item_Grid`, `List_Panel`, `Menu_Tree`, `Widgets`); files also delegates shared non-visual helpers there (`Guikit.Utf8.Editing`, `Guikit.Input.Mouse_Buttons`, `Guikit.Fonts`). files owns the domain (selection, rename, icon assets, localization) and maps it to each component's neutral inputs. **Whether a component is stateful fixes how it integrates — do not re-decide per component:**

- **Stateless render helpers** (`Segmented`, `Item_Grid`, `List_Panel`, `Menu_Tree`, `Widgets`) are called from inside `Build_Frame_Commands`, driven by the snapshot. Prefer this.
- **Stateful overlays** (`Command_Palette`, `Settings_Panel` — they hold query/scroll/focus state across frames) cannot pass through the immutable snapshot: their instance lives in the `Window_Model`, `Files.Overlays` draws them from that state, and the window layer merges the result into the cached frame: `files-application-windows-render_window-present_frame.adb` calls `Append_Overlay`, which is defined in `files-application-windows.adb`.

`Files.Model` keeps the `Window_Model` record and the cross-cutting operations (navigation, focus, text caret, overlay stack); each concern is a public child that sees the private record: one per overlay (`Command_Palette`, `Settings_Pane`, `Root_Selector`, `Sort_Menu`, `Context_Menu`, `Label_Picker`, `Quick_Look`, `Tree_Panel`, `Pasting`, `Clipboard`) and `Selection`, `History` (undo/redo), `Rename`, `Folder_Sizes`, `Status_Samples` and `Jobs` (the foreground/background job state). The overlays stack in one order, `Files.UI_Types.Overlay_Stack`: the model's `Topmost_Overlay`, the keyboard (`Controller.Handle_Key` offers keys to the top overlay only) and the pointer (`Events` routes clicks through `Rendering.Topmost_Overlay_Position`) all follow it. Callers name the child (`Files.Model.Selection.Select_Visible`). **Model children never `with` each other.** What the parent or another child needs from a concern — an overlay's close/reset (so `Close_Overlay` and `Claim_Overlay_Input` reach it), the selection queries the overlays read — lives in the private child `Files.Model.Support`, and the concern's public subprogram renames it; everything only its own child uses stays in that child's body.

## Non-UI layering

Below the UI the units stack one way: `Files.IO.*` (bounded/lease/durable streams, `IO.Errors`) → `Files.Jobs.*` (job records' wire primitives, context journal, process sessions, transports, startup recovery; reaches nothing from `File_System` up, and calls back into it only through the `Jobs.Storage` port — check_all's `Check_Job_Layer` enforces this; it translates nothing either: `Jobs.Scavenger` takes its report text from the caller) → `Files.File_System` (listings and searches take the classification maps, `File_Types.Classification`, and `Types.Listing_Options`, not the settings record) → `Files.Undo.*`, `Files.Model`, `Files.Transfer_Jobs` (the paste copy/move helper job; the model holds its session as a plain `Jobs.Process.Session`) and `Files.Job_Payloads` (settings, listing and operation-result records the job helpers carry) → `Files.Refresh` (incl. `Ensure_Selected_Item_Extra` and `Load_Recent_Items`) → `Files.Operations` (incl. `Operations.Undo_Recording`) → `Files.Job_Drivers.*` (they run `Operations`). Leaf type units every layer may use: `Types` (domain types only), `Text_Case`, `Name_Parts`, `Text_Basics`, `Preference_Types`, `UI_Types`, `Command_Reasons` (why a command is disabled, and its message key). A helper with a single client family is that family's child, not a top-level unit: `Overlays.Command_Palette` and `Overlays.Settings_Form` (the stateful overlays' domain glue), `Controller.Operation_Commands`, `Rendering.Display_Text`, `File_System.Digests` and `File_System.Trash_Info_Codec`, `Model.Selection.Type_Ahead`, `Operations.Archive_Writing` (`Extension_Labels` stays top-level: it rasterizes badge glyphs through raw atlas memory, which the rendering family's no-`System` guardrail rightly refuses); the controller runs pure model commands in its own `Execute_Pure_Command`. Window-layer units used only by `Files.Application.Windows` are `Files.Application.*` children (`Window_Policy`, `Snapshot_Slots`, `Accessibility`, the per-frame `Window_Polls`, and the off-thread readers `Extra_Info_Reader`, `Preview_Decoder` and their `Background_Slots`, …); `Snapshot_Policy` stays top-level because it is `Pure`.

## Localization

`share/files.catalog` and `share/locales/files-*.catalog` are plain-text `key=value` catalogs (default locale at top, keys namespaced like `en.command.view.small`). Generated/converted by the `cldr_to_catalog` tool. Settings use a separate custom format documented in `share/doc/files/settings-format.md`.

## Conventions

- Commits follow conventional-commits style (`feat:`, `fix:`, `refactor:`, etc.).
- For non-trivial changes, propose a short plan and wait for approval before editing.
