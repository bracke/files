separate (Files.Model)
   procedure Clear_Paste_Execution
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Active_Value := False;
      Model.Paste_Exec_Actions_Value.Clear;
      Model.Paste_Exec_Cursor_Value := 0;
      Model.Paste_Exec_Done_Value := 0;
      Model.Paste_Exec_Total_Value := 0;
      Model.Paste_Exec_Mode_Value := Files.File_System.Drop_Copy;
      Model.Paste_Exec_Clears_Clip_Value := True;
      Model.Paste_Exec_Cancelled_Value := False;
      Model.Paste_Exec_Current_Value := Null_Unbounded_String;
      Model.Paste_Exec_First_Dest_Value := Null_Unbounded_String;
      Model.Paste_Exec_Undo_From_Value.Clear;
      Model.Paste_Exec_Undo_To_Value.Clear;
   end Clear_Paste_Execution;
