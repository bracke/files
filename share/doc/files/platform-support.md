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
7. Accessibility trees published through a11y's native AT-SPI, UI Automation,
   and NSAccessibility providers, with semantic validation fallback when the
   host screen-reader service is unavailable.
8. Permission and ownership changes through hostkit's handle-safe metadata
   adapters. Windows maps permission bits to ACLs and round-trips identities
   through SIDs; Linux and macOS use their native metadata interfaces.

Known platform limits:

1. Windows and macOS still need live-window testing in real interactive desktop
   sessions; their CI coverage is build, unit, installation, and headless smoke.
