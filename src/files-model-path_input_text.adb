separate (Files.Model)
   function Path_Input_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Path_Input_Value);
   end Path_Input_Text;
