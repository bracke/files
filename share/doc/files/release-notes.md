# Files Release Notes

This development snapshot focuses on a complete, testable Ada file-manager
vertical slice plus advanced feature depth.

Implemented areas:

1. Startup path normalization and one window model per valid directory.
2. Deterministic directory loading, metadata, sorting, filtering, and selection.
3. View modes for small icons, large icons, and details.
4. Central command registry with toolbar, bottom-bar, keyboard, and palette routes.
5. Settings parsing, editing, saving, reset, and open-action lookup.
6. Trash, permanent delete, rename, create-file, refresh, recursive search, and
   native drop-event queued drop-import operations.
7. Vulkan rendering with textrender text, icon assets, live smoke diagnostics,
   and framebuffer readback hashing.
8. Accessibility bridge export, high-contrast icon profile, and localized UI text.
9. Desktop packaging metadata, AppStream metadata, application icon, and manifest.
10. AUnit model, command, filesystem, rendering, runtime, and packaging coverage.

Known completion limits:

1. Windows and macOS platform bodies need validation on those operating systems.
