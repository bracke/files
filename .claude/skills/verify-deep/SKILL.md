---
name: verify-deep
description: Run the full verification chain for the files project — alr build, alr test (AUnit), and the check_all tool. Use after non-trivial changes to confirm the build, tests, and file-format checks all pass.
---

# verify-deep

Run the project's complete verification chain and report results. Stop and report at the first failing stage — do not continue to the next stage if one fails.

1. **Build** — from the repo root:
   ```
   alr build
   ```
   Style violations (3-space indent, 120-col, casing) surface here as compile errors.

2. **Test** — run the AUnit suite from the `tests/` subdirectory:
   ```
   cd tests && alr test
   ```
   The runner sets a Failure exit status if any case fails.

3. **check_all** — build and run the file-format/compile checker:
   ```
   alr build --root-dir tools -P tools/files_check_all.gpr && tools/bin/check_all
   ```
   (Adjust the invocation if the tool project's build/run differs — confirm the executable path under `tools/`.)

Report a concise pass/fail summary for each stage. On failure, show the relevant error output and the file:line it points to.
