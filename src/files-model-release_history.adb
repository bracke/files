separate (Files.Model)
procedure Release_History
  (Model : in out Window_Model) is
begin
   Retire_Payloads (Model.History.Retired_Releases, Model.History.Undo_Stack);
   Retire_Payloads (Model.History.Retired_Releases, Model.History.Redo_Stack);
   Model.History.Undo_Stack.Clear;
   Model.History.Redo_Stack.Clear;
   Touch (Model);
end Release_History;
