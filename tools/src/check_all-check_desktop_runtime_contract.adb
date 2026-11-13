separate (Check_All)
   procedure Check_Desktop_Runtime_Contract is
      Windows_Body : constant String := Root & "/src/files-application-windows.adb";
      Tests        : constant String := Combined_Suite;
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
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "inotify",
         "window code must not name a Linux-only facility directly; go through Hostkit.Watch");
   end Check_Desktop_Runtime_Contract;
