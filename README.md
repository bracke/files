# files

A desktop file manager written in Ada 2022, rendered with Vulkan and GLFW.

## Platform status

Linux is the validated platform. Windows and macOS platform bindings exist
(`src/platform/windows`, `src/platform/macos`) but are not yet validated.

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

### Build and run

```sh
alr build
bin/files [PATH ...]      # opens at PATH, or the home directory by default
```

Runtime smoke checks are available via `bin/files --runtime-smoke` and
`--live-smoke` (the latter needs Vulkan and a display).

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
