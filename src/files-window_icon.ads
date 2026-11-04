with Glfw.Windows;

--  The files application's window icon: a blue folder, drawn here.
package Files.Window_Icon is

   --  Give Window the files icon.
   --
   --  @param Window GLFW window receiving the icon.
   procedure Set (Window : not null access Glfw.Windows.Window);

end Files.Window_Icon;
