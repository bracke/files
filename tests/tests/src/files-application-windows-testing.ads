with Files.Model;
with Files.Refresh.Watch;

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

   --  Stop a closing window's helpers without waiting for filesystem I/O
   --  (Files.Application.Windows.Release_Window_Jobs).
   --  @param Model Closing window whose transfer, operation and refresh sessions to release.
   --  @param Watch Closing window's native notification session to release.
   procedure Release_Window_Jobs
     (Model : in out Files.Model.Window_Model;
      Watch : in out Files.Refresh.Watch.Watch_Session);

   --  Return desktop runtime capabilities observable without opening a window.
   --
   --  @return Display, Vulkan, and smoke-test readiness flags.
   function Runtime_Capabilities return Desktop_Capabilities;

end Files.Application.Windows.Testing;
