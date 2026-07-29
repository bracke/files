separate (Files.Model)
   procedure Begin_Paste_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Conflict_Active_Value := True;
      Model.Paste_Conflict_Items_Value := Items;
      Model.Paste_Conflict_Existing_Value := Existing;
      Model.Paste_Conflict_Mode_Value := Mode;
      Model.Paste_Conflict_Clears_Clip_Val := Clear_Clipboard;
      Model.Paste_Conflict_Policy_Value := Files.Paste.Policy_Ask;
      Model.Paste_Conflict_Apply_All_Value := False;
      Model.Paste_Conflict_Index_Value := Index;
      Model.Paste_Conflict_Overrides_Value.Clear;
      for Ignore in Items.First_Index .. Items.Last_Index loop
         Model.Paste_Conflict_Overrides_Value.Append (Files.Paste.Decision_Pending);
      end loop;
   end Begin_Paste_Conflict;
