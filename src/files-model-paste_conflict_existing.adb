separate (Files.Model)
function Paste_Conflict_Existing
  (Model : Window_Model)
   return Files.Types.String_Vectors.Vector is
begin
   return Model.Paste_Conflict.Existing;
end Paste_Conflict_Existing;
