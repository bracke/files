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
      Item      : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
      Path      : constant String :=
        GNAT.OS_Lib.Normalize_Pathname (To_String (Item.Full_Path), Resolve_Links => True);
      Old_Mode, Old_Group : Natural;
      Identity : Files.Types.UString;
      Mutation  : constant Files.File_System.Mutation_Result :=
        Files.File_System.Change_Metadata (Path, "", False, New_Mode, 0, Old_Mode, Old_Group, Identity);
   begin
      if not Mutation.Success then
         Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
         return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
      end if;

      declare
         Undo_From    : Files.Types.String_Vectors.Vector;
         Undo_To      : Files.Types.String_Vectors.Vector;
         Undo_Forward : Files.Types.String_Vectors.Vector;
         Identities   : Files.Types.String_Vectors.Vector;
      begin
         Identities.Append (Identity);
         Undo_From.Append (To_Unbounded_String (Path));
         Undo_To.Append (To_Unbounded_String (Natural'Image (Old_Mode)));
         Undo_Forward.Append (To_Unbounded_String (Natural'Image (New_Mode)));
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Set_Permissions, Undo_From, Undo_To,
            Forward => Undo_Forward, Original_Identities => Identities);
      end;

      declare
         Reload : constant Operation_Result :=
           Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Path);
   end;
end Set_Permissions_For;
