# files

A desktop file manager written in Ada 2022, rendered with Vulkan and GLFW.

## Platform status

Linux, Windows, and macOS are all supported targets. Linux is the validated
platform today; the Windows and macOS platform bodies (`src/platform/windows`,
`src/platform/macos`) build per-OS via `files.gpr` and are exercised by the
cross-platform CI matrix (`.github/workflows/ci.yml`), but have not yet been
fully runtime-validated on those operating systems.

## Building

The project is built with [Alire](https://alire.ada.dev/) (`alr`), which provides
the GNAT (Ada 2022) toolchain.

### Sibling crate dependencies

`alire.toml` pins four crates by **local path**, so they must be checked out as
siblings next to this repository:

```
<parent>/
  files/          ← this repository
  project_tools/
  i18n/
  textrender/
  zlib/
```

These are not published Alire crates; clone each one next to `files/` before
building. (`textrender` is at https://github.com/bracke/textrender.)

### System libraries (Linux)

The application links Vulkan, GDK-Pixbuf, and GLib, and needs a TrueType font
for text rendering. On Debian/Ubuntu:

```sh
sudo apt-get install -y \
  libvulkan-dev \
  libgdk-pixbuf-2.0-dev \
  libglib2.0-dev \
  libgtk-3-dev \
  fonts-dejavu-core
```

### System libraries (macOS)

Vulkan on macOS is provided by MoltenVK. With [Homebrew](https://brew.sh/):

```sh
brew install vulkan-headers vulkan-loader molten-vk glfw
```

System fonts under `/System/Library/Fonts` are used for text rendering; set
`FILES_FONT_PATH` to override the chosen font.

### System libraries (Windows)

Install the [Vulkan SDK](https://vulkan.lunarg.com/) (e.g. `choco install
vulkan-sdk`). System fonts under `C:\Windows\Fonts` are used for text
rendering; set `FILES_FONT_PATH` to override.

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
- `live-smoke: SKIP <reason>` — exit `77` (no display or no Vulkan device;
  non-fatal, so environments without a GPU don't fail)

It runs headlessly against the Mesa **lavapipe** software Vulkan driver under a
virtual display:

```sh
sudo apt-get install -y mesa-vulkan-drivers xvfb
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json \
  xvfb-run -a bin/files --live-smoke
```

CI runs exactly this on the Linux job (see `.github/workflows/ci.yml`).

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
  sibling crates (`project_tools`, `i18n`, `textrender`, `zlib`).
- `alire.release.toml` — the **publishable** manifest: identical metadata but
  **no local pins** (it depends on the published crates by wildcard version).

Their versions and dependency sets are kept in sync by the release-readiness
checker, which is built on `project_tools` (`Release_Checks` / `Alire_Manifests`):

```sh
cd tools && alr build && cd ..
tools/bin/release_check
```

To cut a release, run the `/release <version>` workflow (e.g. `/release 0.1.0`).
It bumps both manifests, rolls `share/doc/files/release-notes.md` (a
[Keep a Changelog](https://keepachangelog.com/) changelog), runs the full
verification chain plus `release_check`, and tags `v<version>`.

Publishing to the Alire community index additionally requires that the four
sibling crates are themselves published (the released `files` depends on them
by version, not by path), and is done from `alire.release.toml`.

## License

MIT OR Apache-2.0 WITH LLVM-exception.
