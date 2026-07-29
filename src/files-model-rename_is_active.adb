separate (Files.Model)
   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Rename_Active;
   end Rename_Is_Active;
