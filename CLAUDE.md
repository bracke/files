# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`files` is an Ada 2022 desktop file manager. Core logic (~38K LOC in `src/`) is platform-agnostic; rendering uses Vulkan + GLFW + `textrender`. Linux is the only production-validated platform.

## Build, test, verify

Built with Alire (`alr`), which wraps GNAT and the `.gpr` project files.

- `alr build` — compile the main app. Style is checked at compile time, so a clean build also passes style.
- `alr test` — run the AUnit suite (lives in `tests/`, its own `alire.toml`/`.gpr`).
- check_all — `tools/files_check_all.gpr` builds the `check_all` utility for file-format validation and full GNAT compiles.
- `bin/files [PATH...]` — run the built app (defaults to home dir). `--runtime-smoke` / `--live-smoke` for headless/live validation (needs Vulkan + display).

Verify non-trivial changes with the full chain: `alr build` → `alr test` → check_all. Or run `/verify-deep`.

## Dependencies need sibling checkouts

`alire.toml` pins `project_tools`, `i18n`, and `textrender` to relative paths (`../project_tools`, etc.), not published crates. Builds fail unless those sibling directories exist next to this repo.

## Code style (enforced by the compiler — not just convention)

These come from `config/files_config.gpr` and will **fail the build** if violated:

- 3-space indentation (`-gnaty3`)
- 120-character max line length (`-gnatyM120`) — a hard limit
- Full GNAT style checks (`-gnatya`, casing, layout, spacing) and full warnings (`-gnatwa`)
- UTF-8 source encoding (`-gnatW8`), Ada 2022

## Platform-specific sources

Source dirs are selected by OS: `src/platform/{windows,macos,unsupported}`. Only Linux is validated; treat Windows/macOS bindings as present-but-unverified.

## Localization

`share/files.catalog` and `share/locales/files-*.catalog` are plain-text `key=value` catalogs (default locale at top, keys namespaced like `en.command.view.small`). Generated/converted by the `cldr_to_catalog` tool. Settings use a separate custom format documented in `share/doc/files/settings-format.md`.

## Conventions

- Commits follow conventional-commits style (`feat:`, `fix:`, `refactor:`, etc.).
- For non-trivial changes, propose a short plan and wait for approval before editing.
