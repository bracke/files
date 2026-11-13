separate (Files.Model)
procedure Clear_Undo
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Retire_Payloads (Model.History.Retired_Discards, Model.History.Undo_Stack);
   Retire_Payloads (Model.History.Retired_Discards, Model.History.Redo_Stack);
   Model.History.Undo_Stack.Clear;
   Model.History.Redo_Stack.Clear;
   Model.History.Journal_Dirty := True;
end Clear_Undo;
