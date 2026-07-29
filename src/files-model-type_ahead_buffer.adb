separate (Files.Model)
   function Type_Ahead_Buffer
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Type_Ahead_Buffer_Value);
   end Type_Ahead_Buffer;
