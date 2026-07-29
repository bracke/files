separate (Files.Model)
   procedure Record_Paste_Execution_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Cursor_Value := Model.Paste_Exec_Cursor_Value + 1;
      Model.Paste_Exec_Done_Value := Model.Paste_Exec_Done_Value + 1;
      Model.Paste_Exec_Current_Value := To_Unbounded_String (Name);
      if Length (Model.Paste_Exec_First_Dest_Value) = 0 then
         Model.Paste_Exec_First_Dest_Value := Dest_Path;
      end if;
      Model.Paste_Exec_Undo_From_Value.Append (Dest_Path);
      Model.Paste_Exec_Undo_To_Value.Append (Source_Path);
   end Record_Paste_Execution_Write;
