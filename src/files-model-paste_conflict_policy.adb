separate (Files.Model)
   function Paste_Conflict_Policy
     (Model : Window_Model)
      return Files.Paste.Conflict_Policy is
   begin
      return Model.Paste_Conflict_Policy_Value;
   end Paste_Conflict_Policy;
