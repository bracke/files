separate (Files.Model)
procedure Clear_Paste_Conflict
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Paste_Conflict := (others => <>);
end Clear_Paste_Conflict;
