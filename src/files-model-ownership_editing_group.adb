separate (Files.Model)
function Ownership_Editing_Group
  (Model : Window_Model)
   return Boolean is
begin
   return Model.Ownership_Input.Editing_Group;
end Ownership_Editing_Group;
