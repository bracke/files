separate (Files.Model)
function Paste_Conflict_Is_Active
  (Model : Window_Model)
   return Boolean is
begin
   return Model.Paste_Conflict.Active;
end Paste_Conflict_Is_Active;
