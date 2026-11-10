separate (Files_Suite.Startup)
   procedure Test_Desktop_Runtime_Wiring (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      --  The window's wiring (drops, icon, waiting, the folder watch) is
      --  checked in its own code by check_all's Check_Desktop_Runtime_Contract:
      --  a name found anywhere in src passed even when the hookup was gone.
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
