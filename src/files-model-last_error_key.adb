separate (Files.Model)
   function Last_Error_Key
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Last_Error);
   end Last_Error_Key;
