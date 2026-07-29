separate (Files.Model)
   function Paste_Conflict_Items
     (Model : Window_Model)
      return Files.Paste.Work_Item_Vectors.Vector is
   begin
      return Model.Paste_Conflict_Items_Value;
   end Paste_Conflict_Items;
