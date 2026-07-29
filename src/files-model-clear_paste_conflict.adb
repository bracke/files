separate (Files.Model)
   procedure Clear_Paste_Conflict
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Active_Value := False;
      Model.Paste_Conflict_Items_Value.Clear;
      Model.Paste_Conflict_Existing_Value.Clear;
      Model.Paste_Conflict_Overrides_Value.Clear;
      Model.Paste_Conflict_Policy_Value := Files.Paste.Policy_Ask;
      Model.Paste_Conflict_Mode_Value := Files.File_System.Drop_Copy;
      Model.Paste_Conflict_Index_Value := 0;
      Model.Paste_Conflict_Apply_All_Value := False;
      Model.Paste_Conflict_Clears_Clip_Val := True;
   end Clear_Paste_Conflict;
