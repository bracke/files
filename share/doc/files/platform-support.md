# Files Platform Support

This snapshot is validated on the current Linux desktop environment.

Supported local integrations:

1. Linux directory loading, metadata inspection, root discovery, and trash
   fallback behavior.
2. Vulkan window rendering through GLFW and df_vulkan.
3. Text rendering through textrender.
4. Settings import and export command routing with native-dialog preflight.
5. Windows and macOS platform binding contracts for trash and volume metadata.

Known platform limits:

1. Portable OS drag-event automation requires native event-source backends.
2. Windows and macOS native bindings need validation on those operating systems.
3. Native file dialogs report unavailable status unless a backend is linked.
4. Accessibility data is exported as render metadata, not as an operating-system
   accessibility tree.
