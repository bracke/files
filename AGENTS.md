# Agent Instructions

This repository requires Alire GNAT 15. The development, release, tests, nested
tests, and tools manifests pin `gnat_native = "=15.2.1"`.

Do not run plain system `gnat*`, `gnatmake`, `gnatls`, `gnatprove`, or
`gprbuild` in this workspace. Use `alr exec -- ...` for compiler and builder
commands.

Preferred validation:

```sh
alr exec -- gnatls --version
alr build
alr test
alr exec -- gprbuild -P tools/files_check_all.gpr
tools/bin/release_check
tools/bin/check_all
```
