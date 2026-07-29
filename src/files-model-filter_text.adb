separate (Files.Model)
   function Filter_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Filter_Value);
   end Filter_Text;
