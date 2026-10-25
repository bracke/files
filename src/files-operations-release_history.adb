separate (Files.Operations)
procedure Release_History (Model : in out Files.Model.Window_Model) is
begin
   Files.Model.Release_History (Model);
   Settle_History (Model);
end Release_History;
