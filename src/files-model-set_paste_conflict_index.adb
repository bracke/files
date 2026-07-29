separate (Files.Model)
   procedure Set_Paste_Conflict_Index
     (Model : in out Window_Model;
      Index : Positive) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Index_Value := Index;
   end Set_Paste_Conflict_Index;
