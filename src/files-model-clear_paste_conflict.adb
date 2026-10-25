separate (Files.Model)
procedure Clear_Paste_Conflict
  (Model : in out Window_Model) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Paste_Conflict := (others => <>);
end Clear_Paste_Conflict;
