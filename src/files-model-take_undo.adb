separate (Files.Model)
procedure Take_Undo
  (Model  : in out Window_Model;
   Action : out Undo_Entry;
   Found  : out Boolean) is
begin
   Touch (Model);
   if Model.History.Undo_Stack.Is_Empty then
      Action := (others => <>);
      Found := False;
      return;
   end if;

   Action := Model.History.Undo_Stack.Last_Element;
   Model.History.Undo_Stack.Delete_Last;
   Found := True;
end Take_Undo;
