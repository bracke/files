separate (Files.Model)
   procedure Clear_Clipboard
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Clipboard_Paths_Value.Clear;
      Model.Clipboard_Mode_Value := Clipboard_None;
   end Clear_Clipboard;
