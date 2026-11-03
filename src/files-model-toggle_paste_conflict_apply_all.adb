separate (Files.Model)
procedure Toggle_Paste_Conflict_Apply_All
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Paste_Conflict.Apply_All := not Model.Paste_Conflict.Apply_All;
end Toggle_Paste_Conflict_Apply_All;
