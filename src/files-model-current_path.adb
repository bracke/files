separate (Files.Model)
   function Current_Path
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Current_Path_Value);
   end Current_Path;
