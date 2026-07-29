separate (Files.Model)
   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Redo_Stack.Is_Empty then
         Action := (others => <>);
         Found := False;
         return;
      end if;

      Action := Model.Redo_Stack.Last_Element;
      Model.Redo_Stack.Delete_Last;
      Found := True;
   end Take_Redo;
