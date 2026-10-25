separate (Files.Operations)
procedure Clear_Undo (Model : in out Files.Model.Window_Model) is
begin
   Files.Model.Clear_Undo (Model);
   Settle_History (Model);
end Clear_Undo;
