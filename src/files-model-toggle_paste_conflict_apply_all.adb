separate (Files.Model)
   procedure Toggle_Paste_Conflict_Apply_All
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Apply_All_Value := not Model.Paste_Conflict_Apply_All_Value;
   end Toggle_Paste_Conflict_Apply_All;
