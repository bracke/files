separate (Files.Model)
   function Temporary_Item_Name
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Temporary_Name_Value);
   end Temporary_Item_Name;
