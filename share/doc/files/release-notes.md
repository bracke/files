# Files Release Notes

This development snapshot focuses on a complete, testable Ada file-manager
vertical slice plus advanced feature depth.

Implemented areas:

1. Startup path normalization and one window model per valid directory.
2. Deterministic directory loading, metadata, sorting, filtering, and selection.
3. View modes for small icons, large icons, and details.
4. Central command registry with toolbar, bottom-bar, keyboard, and palette routes.
5. Settings parsing, editing, import/export routing, and open-action lookup.
6. Trash, permanent delete, rename, create-file, refresh, recursive search, and
   drop-import operations.
7. Vulkan rendering with textrender text, icon assets, live smoke diagnostics,
   and framebuffer readback hashing.
8. Accessibility metadata, high-contrast icon profile, and localized UI text.
9. Desktop packaging metadata, AppStream metadata, application icon, and manifest.
10. AUnit model, command, filesystem, rendering, runtime, and packaging coverage.

Known completion limits:

1. Portable OS drag-event automation is not provided by GLFW and requires native
   event-source backends.
2. Windows and macOS platform bodies need validation on those operating systems.
3. Native file dialogs currently report explicit unavailable status unless a
   backend is linked.
4. Native accessibility bridge export is represented as metadata, not yet as an
   operating-system accessibility tree.

