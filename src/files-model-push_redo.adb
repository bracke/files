separate (Files.Model)
procedure Push_Redo
  (Model  : in out Window_Model;
   Action : Undo_Entry) is
begin
   Touch (Model);
   Model.Redo_Stack.Append (Action);
   Model.History_Journal_Dirty := True;
end Push_Redo;
