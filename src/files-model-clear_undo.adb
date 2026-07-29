separate (Files.Model)
   procedure Clear_Undo
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Undo_Stack.Clear;
      Model.Redo_Stack.Clear;
   end Clear_Undo;
