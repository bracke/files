separate (Check_All)
   procedure Check_Desktop_Runtime_Contract is
      Windows_Body : constant String := Root & "/src/files-application-windows.adb";
      Tests        : constant String := Combined_Suite;
      Wait_Body    : constant String := Root & "/src/files-application-windows-event_loop_wait.adb";
      Share_Body   : constant String := Root & "/src/files-application-windows-share_settings_from.adb";
   begin
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glyphs.Missing_Glyph_Count /= 0",
         "headless smoke must not reject otherwise visible frames solely for missing-glyph fallback");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glfw.Windows.Context.Make_Current",
         "desktop Vulkan runtime must not make an OpenGL context current");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glfw.Windows.Context.Swap_Buffers",
         "desktop Vulkan runtime must not swap OpenGL buffers");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glfw.Windows.Context.Set_Swap_Interval",
         "desktop Vulkan runtime must not configure OpenGL swap interval");
      Require_Registered_Routine
        ("Test_Runtime_Capabilities_And_Drop_Events",
         "the test of runtime capabilities and drop events");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Runtime.Last_Missing_Glyph_Count = 0",
         "live smoke must not reject otherwise visible frames solely for missing-glyph fallback");
      --  The window's wiring, in the window's own code (the test suite once
      --  checked these names anywhere in src, which a stale mention passed).
      Require_Contains
        (Windows_Body, "Glfw.Windows.Drop.Paths.Watch", "every window must hand its drops to the import queue");
      Require_Contains
        (Windows_Body, "Handle_Drop_Input", "the event loop must import queued drops");
      Require_Contains (Windows_Body, "Files.Window_Icon.Set", "every window must show the application icon");
      Require_Contains
        (Windows_Body, "Guikit.Vulkan.Wait_For_Events", "the event loop must wait for events, not spin");
      Require_Contains
        (Windows_Body, "Files.Refresh_Jobs.Poll_Watch", "the event loop must poll the folder watch");
      --  The event loop's wait and the cross-window settings sync are decided
      --  by the folds the suite tests (Files.Event_Wait.Fold, and
      --  Files.Settings_Sharing.Share_From with Adopt_Window as its Adopt):
      --  the window subunits only hand them each window's state. A
      --  reimplementation in the subunit would leave the suite testing code
      --  the program no longer runs.
      Require_Contains
        (Wait_Body, "Files.Event_Wait.Fold", "the event loop's wait must be Files.Event_Wait.Fold over the windows");
      Require_Contains
        (Wait_Body, "Event_Wait_Timeout", "the event loop's wait must start the fold from the normal wait");
      Require_Contains
        (Wait_Body, "Mouse_Ready", "the event loop's wait must hand the fold each window's queued mouse change");
      Require_Contains
        (Wait_Body, "Background_Paste", "the event loop's wait must hand the fold each window's background paste");
      Require_Not_Contains
        (Wait_Body,
         "Window_Wait",
         "the event loop's wait must not fold the windows itself; Files.Event_Wait.Fold does");
      Require_Contains
        (Share_Body,
         "Files.Settings_Sharing.Share_From",
         "the settings sync must run Files.Settings_Sharing.Share_From");
      Require_Contains
        (Share_Body,
         "Files.Settings_Sharing.Adopt_Window",
         "a window adopting shared settings must do so through Files.Settings_Sharing.Adopt_Window");
      Require_Not_Contains
        (Share_Body,
         "Adopt_Shared_Settings",
         "a window adopting shared settings must not bypass Files.Settings_Sharing.Adopt_Window");
      Require_Not_Contains
        (Share_Body,
         "Frame_Cache_Valid :=",
         "the frame cache is dropped by Files.Settings_Sharing.Adopt_Window, where the suite sees it");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "inotify",
         "window code must not name a Linux-only facility directly; go through Hostkit.Watch");
   end Check_Desktop_Runtime_Contract;
