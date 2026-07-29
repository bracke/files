separate (Files.Model)
   procedure Set_Paste_Conflict_Policy
     (Model  : in out Window_Model;
      Policy : Files.Paste.Conflict_Policy) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Policy_Value := Policy;
   end Set_Paste_Conflict_Policy;
