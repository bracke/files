separate (Files.Model)
   procedure Record_Paste_Execution_Replaced_Trash
     (Model      : in out Window_Model;
      Trash_Path : Files.Types.UString) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Replaced_Trash_Value.Append (Trash_Path);
   end Record_Paste_Execution_Replaced_Trash;
