separate (Files.Operations.Transfer)
   function Commit_Create_File
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Name : constant String := Files.Model.Rename_Text (Model);
   begin
      if not Files.Model.Temporary_Item_Is_Active (Model) then
         return Disabled (Model, "error.create.no_temporary_item");
      elsif not Files.File_System.Valid_Leaf_Name (Name) then
         Files.Model.Set_Error (Model, "error.name.invalid");
         return Make_Result (Operation_Invalid_Name, "error.name.invalid");
      end if;

      declare
         Path     : constant String := Files.File_System.Join_Path (Files.Model.Current_Path (Model), Name);
         Mutation : constant Files.File_System.Mutation_Result :=
           (if Files.Model.Temporary_Item_Is_Directory (Model)
            then Files.File_System.Create_Directory (Path)
            else Files.File_System.Create_Empty_File (Path));
      begin
         if not Mutation.Success then
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
         end if;
      end;

      --  The file now exists on disk, so leave create-edit mode regardless of
      --  whether the subsequent refresh succeeds; otherwise a refresh failure
      --  would strand the model in temporary-item mode.
      Files.Model.Clear_Edit_State (Model);
      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings, Name);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      Files.Model.Set_Error (Model, "");
      return
        Make_Result
          (Operation_Success,
           Path => Files.File_System.Join_Path (Files.Model.Current_Path (Model), Name));
   end Commit_Create_File;
