# Files Platform Support

This snapshot is validated on the current Linux desktop environment.

Supported local integrations:

1. Linux directory loading, metadata inspection, root discovery, and trash
   fallback behavior.
2. Vulkan window rendering through GLFW and df_vulkan.
3. Text rendering through textrender.
4. Settings editing, saving, and reset through the central settings file.
5. Windows and macOS platform binding contracts for trash and volume metadata.
6. Native GLFW file-drop callbacks routed through the Ada drop event-source
   backend for deterministic queued drop imports.
7. Accessibility nodes exported through the Ada accessibility bridge.

Known platform limits:

1. Windows and macOS native bindings need validation on those operating systems.
