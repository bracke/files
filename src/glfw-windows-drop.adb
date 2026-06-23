package body Glfw.Windows.Drop is
   function Raw_Set_Drop_Callback
     (Window   : System.Address;
      Callback : Raw_Drop_Callback)
      return Raw_Drop_Callback
   with Import, Convention => C, External_Name => "glfwSetDropCallback";

   function Raw_Get_Window_User_Pointer
     (Window : System.Address)
      return System.Address
   with Import, Convention => C, External_Name => "glfwGetWindowUserPointer";

   procedure Set_Drop_Callback
     (Window   : not null access Glfw.Windows.Window;
      Callback : Raw_Drop_Callback)
   is
      Previous : constant Raw_Drop_Callback := Raw_Set_Drop_Callback (Window.Handle, Callback);
   begin
      pragma Unreferenced (Previous);
   end Set_Drop_Callback;

   function User_Pointer
     (Window : System.Address)
      return System.Address is
   begin
      return Raw_Get_Window_User_Pointer (Window);
   end User_Pointer;
end Glfw.Windows.Drop;
