with Files.History_Journal;
separate (Files.Model)
procedure Clear_Undo
  (Model : in out Window_Model) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Discard_Retained (Model.Undo_Stack);
   Discard_Retained (Model.Redo_Stack);
   Model.Undo_Stack.Clear;
   Model.Redo_Stack.Clear;
   Files.History_Journal.Save (Model);
end Clear_Undo;
