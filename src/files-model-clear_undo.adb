separate (Files.Model)
procedure Clear_Undo
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Retire_Payloads (Model.Retired_Discards, Model.Undo_Stack);
   Retire_Payloads (Model.Retired_Discards, Model.Redo_Stack);
   Model.Undo_Stack.Clear;
   Model.Redo_Stack.Clear;
   Model.History_Journal_Dirty := True;
end Clear_Undo;
