# files

A desktop file manager written in Ada 2022, rendered with Vulkan and GLFW.

## Quick start

On Debian/Ubuntu (Linux; see below for macOS/Windows deps):

```sh
# 1. Sibling crates must sit next to this repo (see "Sibling crate dependencies")
#    See the complete sibling list below, including a11ykit (crate name a11y).
# 2. System libraries
sudo apt-get install -y libvulkan-dev libgdk-pixbuf-2.0-dev libglib2.0-dev \
  libgtk-3-dev libssl-dev fonts-dejavu-core fonts-noto-color-emoji
# 3. Build and run (Alire provides the GNAT 15 toolchain)
alr build
bin/files [PATH ...]        # defaults to your home directory
```

Once open: type in the path bar to navigate, double-click or Enter to open,
right-click for the context menu, and press the command palette shortcut to
search commands. Common actions — new file/folder, copy/cut/paste, rename,
duplicate, delete-to-trash (with Undo), compress/extract, open-with — are on the
right-click menu; sorting, view mode, hidden-file visibility, and the theme are
on the bottom bar and in the settings pane.

## Platform status

Long transfers, duplicate, compress/extract, and recursive searches run in helper
processes so the window keeps rendering. Escape or Cancel stops the operation;
completed creations are kept and can be undone. Closing a window stops its helper
without waiting for filesystem I/O. Copies and archives are staged privately and
published only when complete, preserving any destination created concurrently.

Directory refreshes and file watching also run in helpers. The current listing
stays usable while a refresh is pending, and results apply only to the view
that requested them. Paste completion and cancellation do not wait for a reload.

Replace keeps the overwritten item available for rollback and Undo. On native
trash backends this uses an adjacent private `.files-recovery-*` directory. An
ownership record binds the directory identity, original pathname, and `payload`;
an application-data index makes retained payloads discoverable after restart. A
failed rollback leaves that payload in place and records a recovery Undo action.
If the original name is occupied, preserve the occupying item elsewhere and
retry Undo. After a crash, use `files --list-recoveries` to list the global
index, `files --list-recoveries DIRECTORY` to scan one directory, or
`files --recover PAYLOAD` / `files --discard-recovery PAYLOAD` to resolve it.

Linux, Windows, and macOS are all supported targets. Linux is the validated
platform today; the Windows and macOS adapters live in the `hostkit` sibling
and are exercised by the
cross-platform CI matrix (`.github/workflows/ci.yml`), but have not yet been
fully runtime-validated on those operating systems.

## Building

The project is built with [Alire](https://alire.ada.dev/) (`alr`) and must use
Alire GNAT 15. The development, release, tests, and tools manifests
pin `gnat_native = "=15.2.1"`. Confirm with:

```sh
alr exec -- gnatls --version
```

Do not run plain system `gnat*`, `gnatmake`, `gnatls`, `gnatprove`, or
`gprbuild` in this workspace. Use `alr exec -- ...` for compiler and builder
commands so PATH cannot select a different GNAT installation.

### Sibling crate dependencies

`alire.toml` pins runtime crates by **local path**, so they must be checked out as
siblings next to this repository:

```
<parent>/
  files/          ← this repository
  project_tools/
  hostkit/
  messages/
  i18n/
  textrender/
  zlib/
  cryptolib/
  guikit/
  a11ykit/        ← Alire crate name: a11y
```

Clone each pinned crate next to `files/` before building. `project_tools` is
needed by tests and repository checks. The i18n regeneration tools also need
the `httpclient`, `tarlib`, `awklib`, and `regexp` siblings, as checked out by CI.

### System libraries (Linux)

The application links Vulkan, GDK-Pixbuf, and GLib, and needs a TrueType font
for text rendering. On Debian/Ubuntu:

```sh
sudo apt-get install -y \
  libvulkan-dev \
  libgdk-pixbuf-2.0-dev \
  libglib2.0-dev \
  libgtk-3-dev \
  libssl-dev \
  fonts-dejavu-core \
  fonts-noto-color-emoji
```

### System libraries (macOS)

Vulkan on macOS is provided by MoltenVK. With [Homebrew](https://brew.sh/):

```sh
brew install vulkan-headers vulkan-loader molten-vk glfw gdk-pixbuf openssl@3
```

System fonts under `/System/Library/Fonts` are used for text rendering; set
`FILES_FONT_PATH` to override the chosen font.

### System libraries (Windows)

Use the preinstalled MSYS2 shell on GitHub runners, or install
[MSYS2](https://www.msys2.org/) locally, then install libraries for the same
MinGW-w64 ABI used by Alire GNAT:

```sh
pacman -S --needed mingw-w64-x86_64-vulkan-loader \
  mingw-w64-x86_64-glib2 mingw-w64-x86_64-gdk-pixbuf2 \
  mingw-w64-x86_64-glfw mingw-w64-x86_64-openssl
```

Set `CPATH` to `C:/msys64/mingw64/include`, `LIBRARY_PATH` to
`C:/msys64/mingw64/lib`, and add `C:\msys64\mingw64\bin` to `PATH`. The LunarG
SDK's MSVC `.lib` files are not compatible with GNAT's MinGW linker. System
fonts under `C:\Windows\Fonts` are used for text rendering; set
`FILES_FONT_PATH` to override.

### Build and run

```sh
alr build
bin/files [PATH ...]      # opens at PATH, or the home directory by default
```

Runtime smoke checks are available via `bin/files --runtime-smoke` and
`--live-smoke`. `--runtime-smoke` is fully headless (it builds frames, rasterizes
glyphs, and reports counts without a window or GPU).

`--live-smoke` exercises the **full GLFW + Vulkan render path**: it opens a
window, presents real frames, reads the framebuffer back, and structurally
analyses it (that it is not blank, the background does not fill the frame, there
is meaningful drawn "ink", and each of the top/middle/bottom bands has content).
This gate covers the display layer that the headless AUnit suite cannot reach.
It reports a canonical verdict line and exit code:

- `live-smoke: PASS` — exit `0`
- `live-smoke: FAIL <reason>` — exit `1` (a degenerate frame; fails CI)
- `live-smoke: SKIP <reason>` — exit `77` (no display or no Vulkan device)

It runs headlessly against the Mesa **lavapipe** software Vulkan driver under a
virtual display:

```sh
sudo apt-get install -y mesa-vulkan-drivers xvfb
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json \
  xvfb-run -a bin/files --live-smoke
```

CI provisions both dependencies and therefore requires `PASS`; a `SKIP` fails
the Linux job rather than hiding a broken runner configuration.

## Tests

The AUnit suite lives in `tests/` (its own Alire crate):

```sh
cd tests
alr build
./bin/tests
```

The test runner pins `LC_ALL=C` so results are deterministic regardless of the
machine's locale.

## Code style

Style is enforced at compile time (see `config/files_config.gpr`): 3-space
indentation, a hard 120-column line limit, full GNAT style checks and warnings,
UTF-8 source encoding, and Ada 2022.

## Documentation

- [`share/doc/files/quick-start.md`](share/doc/files/quick-start.md)
- [`share/doc/files/settings-format.md`](share/doc/files/settings-format.md)
- [`share/doc/files/platform-support.md`](share/doc/files/platform-support.md)
- [`share/doc/files/release-notes.md`](share/doc/files/release-notes.md)

## Releasing

The crate uses two Alire manifests:

- `alire.toml` — the **development** manifest, with local-path pins to the
  runtime sibling crates listed above.
- `alire.release.toml` — the **publishable** manifest: identical metadata but
  **no local pins** (it depends on published crates through explicit compatible
  or exact version constraints).

Their versions and dependency sets are kept in sync by the release-readiness
checker, which is built on `project_tools` (`Release_Checks` / `Alire_Manifests`):

```sh
cd tools && alr build && cd ..
tools/bin/release_check
tools/bin/check_all
```

To cut a release, run the `/release <version>` workflow (e.g. `/release 0.1.0`).
It bumps both manifests, rolls `share/doc/files/release-notes.md` (a
[Keep a Changelog](https://keepachangelog.com/) changelog), runs the full
verification chain plus `release_check`, and tags `v<version>`.

Publishing to the Alire community index additionally requires that the runtime
sibling crates are themselves published (the released `files` depends on them
by version, not by path), and is done from `alire.release.toml`.

## License

Licensed under either of

- MIT ([LICENSE-MIT](LICENSE-MIT)), or
- Apache License, Version 2.0 with the LLVM exception
  ([LICENSE-APACHE](LICENSE-APACHE))

at your option.
