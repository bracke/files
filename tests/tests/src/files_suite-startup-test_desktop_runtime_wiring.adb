separate (Files_Suite.Startup)
   procedure Test_Desktop_Runtime_Wiring (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert
        (Files_Suite.Repository.Source_Contains ("glfwSetDropCallback")
         and then Files_Suite.Repository.Source_Contains ("Handle_Drop_Input"),
         "native file-drop callbacks are connected to controller import routing");
      Assert
        (Files_Suite.Repository.Source_Contains ("glfwSetWindowIcon")
         and then Files_Suite.Repository.Source_Contains ("Glfw.Windows.Icon.Set_Files_Icon"),
         "native desktop windows receive the packaged application icon");
      Assert
        (Files_Suite.Repository.Source_Contains ("Guikit.Vulkan.Wait_For_Events")
         and then Files_Suite.Repository.Source_Contains ("Handle_File_Watch_Poll"),
         "directory file watching is polled from the desktop event loop");
      --  Native watching is connected to the event loop through a per-host
      --  seam, not by calling a kernel facility from window code: inotify is
      --  Linux-only, and naming it here once made the application impossible to
      --  link on macOS or Windows. That seam is now Hostkit.Watch, so the
      --  per-host bodies -- and the assertion that each host supplies its own
      --  inotify/kqueue/FindFirstChangeNotification -- live in hostkit with
      --  them. What files still owns, and what this checks, is the wiring.
      Assert
        (Files_Suite.Repository.Source_Contains ("Hostkit.Watch.Poll")
         and then Files_Suite.Repository.Source_Contains ("Drain_Native_Watch"),
         "native file watching is connected to the desktop event loop");
      --  "window code must not name inotify directly" is now a family-aware
      --  guardrail in check_all (Check_Desktop_Runtime_Contract), so it covers
      --  the window body and every one of its subunits, not just one file.
      Assert
        (Files_Suite.Repository.Source_Contains ("Root_Network_Mount")
         and then Files_Suite.Repository.File_Contains ("share/files.catalog", "en.root.network_mount.prefix = "),
         "root discovery includes network-specific root handling");
      declare
         Display_Available : constant Boolean := Files.Application.Windows.Live_Display_Available;
         Vulkan_Available  : constant Boolean := Files.Application.Windows.Vulkan_Runtime_Available;
         Capabilities      : constant Files.Application.Windows.Desktop_Capabilities :=
           Files.Application.Windows.Runtime_Capabilities;
      begin
         Files_Suite.Support.Assert_Equal
           (Capabilities.Display_Available,
            Display_Available,
            "desktop capability report includes display state");
         Files_Suite.Support.Assert_Equal
           (Capabilities.Vulkan_Available,
            Vulkan_Available,
            "desktop capability report includes Vulkan state");
      end;
   end Test_Desktop_Runtime_Wiring;
