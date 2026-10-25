separate (Files.Model)
function Paste_Conflict_Clears_Clipboard
  (Model : Window_Model)
   return Boolean is
begin
   return Model.Paste_Conflict.Clears_Clipboard;
end Paste_Conflict_Clears_Clipboard;
