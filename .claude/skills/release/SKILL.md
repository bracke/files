---
name: release
description: Cut a release of the files crate — bump the version in both manifests, roll the changelog, run the full verification + release-readiness checks, and tag. Triggered by the user with the new version, e.g. /release 0.1.0.
disable-model-invocation: true
---

# release

Cut a release of `files`. The argument is the new release version (SemVer, no
`-dev` suffix), e.g. `/release 0.1.0`. Treat each step as a gate: stop and
report if any step fails; never tag a release that did not pass every check.

Let `VERSION = $ARGUMENTS` and `TODAY` = today's date (`YYYY-MM-DD`).

1. **Preconditions.**
   - Confirm a clean working tree (`git status --short` is empty). If dirty, stop.
   - Confirm `VERSION` is a valid SemVer without a `-dev` suffix. If missing or a
     dev snapshot, ask the user for the release version and stop.
   - Confirm the release notes `## [Unreleased]` section is non-empty (there is
     something to release).

2. **Bump both manifests.** Set `version = "VERSION"` in **both** `alire.toml`
   and `alire.release.toml` (they must stay in sync — `release_check` enforces
   this). Change nothing else in them.

3. **Roll the changelog** (`share/doc/files/release-notes.md`):
   - Rename the `## [Unreleased]` heading to `## [VERSION] - TODAY`.
   - Insert a fresh empty `## [Unreleased]` section above it (with empty
     `### Added` / `### Changed` / `### Fixed` subheads).

4. **Verify** — run the full chain from the repo root; stop at the first failure:
   - `alr build`
   - `cd tests && alr build && ./bin/tests` (expect all green), then `cd ..`
   - `cd tools && alr build && cd ..`
   - `tools/bin/check_all`
   - `tools/bin/release_check`

5. **Commit and tag.**
   - `git add alire.toml alire.release.toml share/doc/files/release-notes.md`
   - Commit: `release: files VERSION` (conventional-commits style; end the body
     with the Co-Authored-By trailer per the project convention).
   - Tag: `git tag -a vVERSION -m "files VERSION"`.

6. **Report and hand off publishing.** Summarize what was tagged. Remind the
   user that publishing to the Alire community index has prerequisites this
   skill does **not** perform:
   - The sibling crates (`project_tools`, `i18n`, `textrender`, `zlib`) must be
     published first, since the published `files` crate depends on them by
     wildcard version (see `alire.release.toml`).
   - Push the branch and the tag (the environment has no push credentials, so
     the user runs this), then publish from the pin-free release manifest
     (`alr publish`, using `alire.release.toml` rather than the pinned
     development `alire.toml`).

   Do not push or run `alr publish` yourself.
