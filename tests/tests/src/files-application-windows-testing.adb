package body Files.Application.Windows.Testing is

   function Live_Display_Available return Boolean renames Files.Application.Windows.Live_Display_Available;

   function Vulkan_Runtime_Available return Boolean renames Files.Application.Windows.Vulkan_Runtime_Available;

end Files.Application.Windows.Testing;
