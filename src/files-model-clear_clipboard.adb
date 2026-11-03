separate (Files.Model)
procedure Clear_Clipboard
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Clipboard_Paths_Value.Clear;
   Model.Clipboard_Mode_Value := Clipboard_None;
end Clear_Clipboard;
