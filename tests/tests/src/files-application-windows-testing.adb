package body Files.Application.Windows.Testing is

   function Live_Display_Available return Boolean renames Files.Application.Windows.Live_Display_Available;

   function Vulkan_Runtime_Available return Boolean renames Files.Application.Windows.Vulkan_Runtime_Available;

   procedure Release_Window_Jobs
     (Model : in out Files.Model.Window_Model;
      Watch : in out Files.Refresh.Watch.Watch_Session)
     renames Files.Application.Windows.Release_Window_Jobs;

   function Runtime_Capabilities return Desktop_Capabilities
     renames Files.Application.Windows.Runtime_Capabilities;

end Files.Application.Windows.Testing;
