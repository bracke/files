separate (Files.Model)
procedure Push_Undo
  (Model  : in out Window_Model;
   Action : Undo_Entry) is
begin
   Touch (Model);
   Model.History.Undo_Stack.Append (Action);
   Model.History.Journal_Dirty := True;
end Push_Undo;
