separate (Files.Model)
   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Redo_Stack.Append (Action);
   end Push_Redo;
