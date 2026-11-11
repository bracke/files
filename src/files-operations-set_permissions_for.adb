separate (Files.Operations)
function Set_Permissions_For
  (Model    : in out Files.Model.Window_Model;
   New_Mode : Natural;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
begin
   if not Permissions_Editable_Selection (Model) then
      return Disabled (Model, "error.selection.empty");
   end if;

   declare
      Item      : constant Files.Items.Directory_Item := Files.Model.Selected_Item (Model);
      Path      : constant String :=
        Files.Fs_Primitives.Full_Name (To_String (Item.Full_Path));
      Old_Mode : Natural;
      Identity : Files.Types.UString;
      Mutation  : constant Files.File_System.Mutation_Result :=
        Files.File_System.Change_Mode (Path, "", New_Mode, Old_Mode, Identity);
   begin
      if not Mutation.Success then
         Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
         return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
      end if;

      return Finish_Attribute_Change
        (Model, Settings, Files.Model.Undo_Set_Permissions, Path, Identity,
         Old_Text => Files.Undo_Payloads.Mode_Text (Old_Mode),
         New_Text => Files.Undo_Payloads.Mode_Text (New_Mode));
   end;
end Set_Permissions_For;
