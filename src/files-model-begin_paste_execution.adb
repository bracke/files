separate (Files.Model)
   procedure Begin_Paste_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
   is
      Writes : Natural := 0;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Action of Actions loop
         if not Action.Skip then
            Writes := Writes + 1;
         end if;
      end loop;

      Model.Paste_Exec_Active_Value := True;
      Model.Paste_Exec_Actions_Value := Actions;
      Model.Paste_Exec_Cursor_Value := 0;
      Model.Paste_Exec_Done_Value := 0;
      Model.Paste_Exec_Total_Value := Writes;
      Model.Paste_Exec_Mode_Value := Mode;
      Model.Paste_Exec_Clears_Clip_Value := Clear_Clipboard;
      Model.Paste_Exec_Cancelled_Value := False;
      Model.Paste_Exec_Current_Value := Null_Unbounded_String;
      Model.Paste_Exec_First_Dest_Value := Null_Unbounded_String;
      Model.Paste_Exec_Undo_From_Value.Clear;
      Model.Paste_Exec_Undo_To_Value.Clear;
      Model.Paste_Exec_Replaced_Trash_Value.Clear;
   end Begin_Paste_Execution;
