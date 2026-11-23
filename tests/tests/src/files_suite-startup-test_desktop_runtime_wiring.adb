with Files.Application.Windows.Testing;
separate (Files_Suite.Startup)
   procedure Test_Desktop_Runtime_Wiring (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      --  The window's wiring (drops, icon, waiting, the folder watch) is
      --  checked in its own code by check_all's Check_Desktop_Runtime_Contract.
      declare
         Display_Available : constant Boolean := Files.Application.Windows.Testing.Live_Display_Available;
         Vulkan_Available  : constant Boolean := Files.Application.Windows.Testing.Vulkan_Runtime_Available;
         Capabilities      : constant Files.Application.Windows.Desktop_Capabilities :=
           Files.Application.Windows.Testing.Runtime_Capabilities;
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
