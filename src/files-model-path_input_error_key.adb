separate (Files.Model)
   function Path_Input_Error_Key
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Path_Input_Error);
   end Path_Input_Error_Key;
