# Files Quick Start

`files` is an Ada desktop file explorer for local directories.

Run `bin/files` with no arguments to open the current user's home directory.
Run `bin/files PATH` to open a directory, or the parent directory of a file.
Multiple path arguments open multiple window models.

Common keyboard commands:

1. `Control+1` selects small icons.
2. `Control+2` selects large icons.
3. `Control+3` selects details.
4. `Control+4` toggles the information pane when an item is selected.
5. `Control+L` focuses the path input.
6. `Control+F` focuses the filter input.
7. `Control+Shift+F` clears the filter.
8. `Control+A` selects every visible item.
9. `Control+P` opens or closes the command palette.
10. `Delete` and `Backspace` move selected items to trash.
11. `Shift+Delete` permanently deletes selected items through the advanced command.
12. `F2` toggles rename mode for the selected item.
13. `Return` commits focused text fields or opens the selected item.

The command palette exposes the same central command identifiers as toolbar,
bottom-bar, mouse, and keyboard routes.

## Recovery payloads

When an overwrite cannot use a trash backend that supports programmatic
restore, Files retains the previous destination beside it in a private
`.files-recovery-*` directory. These payloads normally disappear when their
Undo entry is used, cleared, or expires. After a crash, inspect and resolve any
remaining payload explicitly:

```sh
files --list-recoveries DIRECTORY
files --recover DIRECTORY/.files-recovery-N/payload
files --discard-recovery DIRECTORY/.files-recovery-N/payload
```

Listing prints the payload and its recorded original path, separated by a tab.
Recovery refuses to replace an existing destination. Discard is permanent and
accepts only a recognized Files recovery payload.
