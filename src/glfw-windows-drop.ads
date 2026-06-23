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

   --  Return the Ada window object user pointer attached to a raw GLFW window.
   --
   --  @param Window Raw GLFW window pointer supplied by a native callback.
   --  @return User pointer previously attached by OpenGLAda window initialization.
   function User_Pointer
     (Window : System.Address)
      return System.Address;
end Glfw.Windows.Drop;
