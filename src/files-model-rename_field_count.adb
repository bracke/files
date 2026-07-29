separate (Files.Model)
   function Rename_Field_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Rename_Fields.Length);
   end Rename_Field_Count;
