separate (Files.Model)
   function Rename_Text
     (Model : Window_Model)
      return String is
   begin
      return First_Rename_Value (Model);
   end Rename_Text;
