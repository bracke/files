with Files.Model.Ownership_Input;
separate (Files.Operations)
procedure Focus_Ownership_Input
  (Model         : in out Files.Model.Window_Model;
   Editing_Group : Boolean) is
begin
   if not Files.File_System.Permissions.Supports_Ownership
     or else Files.Model.Selection.Selected_Count (Model) /= 1
   then
      return;
   end if;
   declare
      Item : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
   begin
      Files.Model.Ownership_Input.Focus_Ownership_Input
        (Model,
         Editing_Group,
         (if Editing_Group
          then Files.File_System.Permissions.Group_Name_For_Id (Item.Group_Id)
          else Files.File_System.Permissions.User_Name_For_Id (Item.Owner_Id)));
   end;
end Focus_Ownership_Input;
