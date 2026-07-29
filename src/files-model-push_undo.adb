separate (Files.Model)
   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Undo_Stack.Append (Action);
   end Push_Undo;
