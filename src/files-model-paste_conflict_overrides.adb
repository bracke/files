separate (Files.Model)
   function Paste_Conflict_Overrides
     (Model : Window_Model)
      return Files.Paste.Item_Decision_Vectors.Vector is
   begin
      return Model.Paste_Conflict_Overrides_Value;
   end Paste_Conflict_Overrides;
