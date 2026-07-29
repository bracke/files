separate (Files.Model)
   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Temporary_Active;
   end Temporary_Item_Is_Active;
