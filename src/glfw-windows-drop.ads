with Interfaces.C;
with System;

--  Native GLFW file-drop callback bridge.
package Glfw.Windows.Drop is
   type Raw_Drop_Callback is access procedure
     (Window : System.Address;
      Count  : Interfaces.C.int;
      Paths  : System.Address)
   with Convention => C;

   --  Install a native GLFW file-drop callback for Window.
   --
   --  @param Window GLFW window that receives file-drop callbacks.
   --  @param Callback C-compatible callback to install.
   procedure Set_Drop_Callback
     (Window   : not null access Glfw.Windows.Window;
      Callback : Raw_Drop_Callback);

   --  Return the raw GLFW window handle for Window.
   --
   --  @param Window Ada GLFW window object.
   --  @return Raw GLFWwindow pointer.
   function Raw_Handle
     (Window : not null access Glfw.Windows.Window)
      return System.Address;
end Glfw.Windows.Drop;
