separate (Files.Model)
   function Quick_Look_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Quick_Look_Active;
   end Quick_Look_Is_Open;
