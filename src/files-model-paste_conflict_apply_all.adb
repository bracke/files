separate (Files.Model)
   function Paste_Conflict_Apply_All
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict_Apply_All_Value;
   end Paste_Conflict_Apply_All;
