separate (Files.Model)
procedure Take_Redo
  (Model  : in out Window_Model;
   Action : out Undo_Entry;
   Found  : out Boolean) is
begin
   Touch (Model);
   if Model.History.Redo_Stack.Is_Empty then
      Action := (others => <>);
      Found := False;
      return;
   end if;

   Action := Model.History.Redo_Stack.Last_Element;
   Model.History.Redo_Stack.Delete_Last;
   Found := True;
end Take_Redo;
