separate (Files.Model)
   function Temporary_Item_Is_Directory
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Temporary_Is_Directory;
   end Temporary_Item_Is_Directory;
