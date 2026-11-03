separate (Files.Model)
procedure Push_Undo
  (Model  : in out Window_Model;
   Action : Undo_Entry) is
begin
   Touch (Model);
   Model.Undo_Stack.Append (Action);
   Model.History_Journal_Dirty := True;
end Push_Undo;
