--  Native GLFW window icon helpers.
package Glfw.Windows.Icon is

   --  Set the files application icon on Window.
   --
   --  @param Window GLFW window receiving the icon.
   procedure Set_Files_Icon
     (Window : not null access Glfw.Windows.Window);

end Glfw.Windows.Icon;
