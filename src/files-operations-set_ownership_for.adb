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
      Item      : constant Files.Items.Directory_Item := Files.Model.Selected_Item (Model);
      Path      : constant String :=
        GNAT.OS_Lib.Normalize_Pathname (To_String (Item.Full_Path), Resolve_Links => True);
      New_User_Name : constant String :=
        Files.File_System.User_Name_For_Id (User_Id);
      New_Group_Name : constant String :=
        Files.File_System.Group_Name_For_Id (Group_Id);
      Old_Uid, Old_Gid : Files.Types.Account_Id;
      Identity : Files.Types.UString;
      Mutation  : constant Files.File_System.Mutation_Result :=
        Files.File_System.Change_Ownership
          (Path, "", User_Id, Group_Id, Old_Uid, Old_Gid,
           Identity, New_User_Name, New_Group_Name);
   begin
      if not Mutation.Success then
         Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
         return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
      end if;

      return Finish_Attribute_Change
        (Model, Settings, Files.Model.Undo_Set_Ownership, Path, Identity,
         Old_Text =>
           Ownership_Text
             (Old_Uid, Old_Gid,
              Files.File_System.User_Name_For_Id (Old_Uid), Files.File_System.Group_Name_For_Id (Old_Gid)),
         New_Text => Ownership_Text (User_Id, Group_Id, New_User_Name, New_Group_Name));
   end;
end Set_Ownership_For;
