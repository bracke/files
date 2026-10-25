separate (Files.Model)
procedure Release_History
  (Model : in out Window_Model) is
begin
   Retire_Payloads (Model.Retired_Releases, Model.Undo_Stack);
   Retire_Payloads (Model.Retired_Releases, Model.Redo_Stack);
   Model.Undo_Stack.Clear;
   Model.Redo_Stack.Clear;
   Model.Revision_Value := Model.Revision_Value + 1;
end Release_History;
