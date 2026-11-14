separate (Files.Operations)
function Set_Ownership_For
  (Model    : in out Files.Model.Window_Model;
   User_Id  : Files.Types.Account_Id;
   Group_Id : Files.Types.Account_Id;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
begin
   if not Ownership_Editable_Selection (Model) then
      return Disabled (Model, "error.selection.empty");
   end if;

   declare
      use type Files.Types.Account_Id;
      Item      : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
      Path      : constant String :=
        Files.Fs_Primitives.Full_Name (To_String (Item.Full_Path));
      Keep_User : constant Boolean := User_Id = Hostkit.Metadata.Keep_Id;
      Keep_Group : constant Boolean := Group_Id = Hostkit.Metadata.Keep_Id;
      New_User_Name : constant String :=
        (if Keep_User then "" else Files.File_System.Permissions.User_Name_For_Id (User_Id));
      New_Group_Name : constant String :=
        (if Keep_Group then "" else Files.File_System.Permissions.Group_Name_For_Id (Group_Id));
      Old_Uid, Old_Gid : Files.Types.Account_Id;
      Identity : Files.Types.UString;
      Mutation  : constant Files.File_System.Mutation_Result :=
        Files.File_System.Permissions.Change_Ownership
          (Path, "", User_Id, Group_Id, Old_Uid, Old_Gid,
           Identity, New_User_Name, New_Group_Name);
   begin
      if not Mutation.Success then
         Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
         return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
      end if;

      declare
         --  What the file now has: a kept id is the one it had.
         Applied_User  : constant Files.Types.Account_Id := (if Keep_User then Old_Uid else User_Id);
         Applied_Group : constant Files.Types.Account_Id := (if Keep_Group then Old_Gid else Group_Id);
      begin
         return Finish_Attribute_Change
           (Model, Settings, Files.Model.Undo_Set_Ownership, Path, Identity,
            Old_Text =>
              Ownership_Text
                (Old_Uid, Old_Gid,
                 Files.File_System.Permissions.User_Name_For_Id (Old_Uid),
                 Files.File_System.Permissions.Group_Name_For_Id (Old_Gid)),
            New_Text =>
              Ownership_Text
                (Applied_User, Applied_Group,
                 (if Keep_User then Files.File_System.Permissions.User_Name_For_Id (Applied_User)
                  else New_User_Name),
                 (if Keep_Group then Files.File_System.Permissions.Group_Name_For_Id (Applied_Group)
                  else New_Group_Name)));
      end;
   end;
end Set_Ownership_For;
