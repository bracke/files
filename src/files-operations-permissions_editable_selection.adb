separate (Files.Operations)
   function Permissions_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is
      Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
   begin
      return Files.Model.Selected_Count (Model) = 1
        and then not Files.Model.Selection_Includes_Temporary (Model)
        and then Files.File_System.Supports_Permissions
        and then Item.Mode_Available
        and then Files.Model.Current_Path (Model) /= Files.File_System.Trash_Files_Directory;
   end Permissions_Editable_Selection;
