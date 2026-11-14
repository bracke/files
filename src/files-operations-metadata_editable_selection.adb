separate (Files.Operations)
function Metadata_Editable_Selection
  (Model : Files.Model.Window_Model;
   What  : Editable_Metadata)
   return Boolean
is
   Item : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
begin
   return Files.Model.Selection.Selected_Count (Model) = 1
     and then not Files.Model.Selection.Selection_Includes_Temporary (Model)
     and then
       (case What is
           when Ownership_Metadata   =>
              Files.File_System.Supports_Ownership and then Item.Ownership_Available,
           when Permissions_Metadata =>
              Files.File_System.Supports_Permissions and then Item.Mode_Available)
     and then not Files.File_System.Is_Trash_Files_Directory
                    (Files.Model.Current_Path (Model));
end Metadata_Editable_Selection;
