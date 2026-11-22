--  What the suite reaches of Files.Application.Windows that is not part of its interface.
package Files.Application.Windows.Testing is

   --  Return whether a live desktop display appears available.
   --
   --  @return True when the environment advertises a display/session endpoint.
   function Live_Display_Available return Boolean;

   --  Return whether Vulkan support is advertised by GLFW.
   --
   --  @return True when GLFW reports Vulkan support after initialization.
   function Vulkan_Runtime_Available return Boolean;

end Files.Application.Windows.Testing;
