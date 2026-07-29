separate (Files.Model)
   function Item_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Items.Length);
   end Item_Count;
