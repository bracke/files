# Files Platform Support

This snapshot has full live-window validation on Linux. CI also builds, links,
runs the AUnit suite, checks the installed package, and exercises the headless
render path on Windows and macOS; those runners do not provide interactive GUI
session validation.

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

1. Windows and macOS still need live-window testing in real interactive desktop
   sessions; their CI coverage is build, unit, installation, and headless smoke.
2. Permission and ownership changes require the native handle-safe metadata
   adapter. Linux and macOS provide it; Windows currently fails the operation
   rather than using a pathname sequence that could modify a replaced entry.
