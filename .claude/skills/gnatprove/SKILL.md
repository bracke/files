---
name: gnatprove
description: Run SPARK gnatprove formal verification over the files project (or a specific unit). Use to check SPARK contracts, prove absence of run-time errors, or verify a unit marked with SPARK_Mode. Requires the SPARK/gnatprove toolchain to be installed.
---

# gnatprove

Run SPARK formal verification with `gnatprove` against this project's GNAT project file (`files.gpr`).

## Prerequisites

- `gnatprove` must be installed (part of the SPARK toolset). Check with `gnatprove --version` (or `alr exec -- gnatprove --version`). If it isn't installed, tell the user — it ships with SPARK Pro or the FSF SPARK community release / an Alire SPARK crate; don't try to install it silently.
- Only units (or regions) marked `SPARK_Mode => On` are analyzed. If none are marked, gnatprove will report little to prove — say so rather than implying the code was verified.

## Running

From the repo root, run inside the Alire environment so dependencies and switches resolve:

```
alr exec -- gnatprove -P files.gpr -j0 --level=2 --output=brief
```

- `-j0` — use all cores.
- `--level=0..4` — proof effort/time trade-off. Start at `2`; raise to `3`/`4` only for units that don't prove and you suspect need more effort.
- `--output=brief` — concise messages. Drop it for full detail.

To verify a single unit instead of the whole project, add `-u <unit>` (e.g. `-u files-model`) or pass the file:

```
alr exec -- gnatprove -P files.gpr -j0 --level=2 -u files-model
```

Useful extra modes:
- `--mode=flow` — data/flow analysis only (fast; catches uninitialized data, aliasing).
- `--mode=prove` — proof of run-time safety and contracts (the default `all` does both).
- `--report=all` — also list checks that were proved, not just failures.

## Reporting

Summarize: which checks were proved, which are unproved (with the file:line and the kind of check — e.g. "overflow check might fail"), and any flow warnings. For unproved checks, suggest the next step (add a contract/loop invariant, strengthen a precondition, or raise `--level`). Do not claim the code is "proven correct" unless gnatprove reports all checks proved with no warnings.
