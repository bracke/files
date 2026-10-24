separate (Files_Suite.Operations)
   procedure Test_Empty_Trash_Partial_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_empty_partial_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Keep_File    : constant String := Join (Root, "purge-me.txt");
      Locked_Dir   : constant String := Join (Root, "locked-dir");
      Locked_Child : constant String := Join (Locked_Dir, "inside.txt");
      Trashed_Lock : constant String := Join (Trash_File, "locked-dir");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;

      procedure Restore_Environment is
      begin
         --  Re-open the locked payload so the fixture tree can be removed.
         declare
            Unlocked : constant Files.File_System.Mutation_Result :=
              Files.File_System.Set_Permissions (Trashed_Lock, 8#755#);
            pragma Unreferenced (Unlocked);
         begin
            null;
         end;

         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  One ordinary file plus one non-empty directory, both trashed.
      Write_File (Keep_File, "purge");
      Ada.Directories.Create_Path (Locked_Dir);
      Write_File (Locked_Child, "child");
      declare
         Trash_Keep : constant Files.File_System.Mutation_Result := Files.File_System.Move_To_Trash (Keep_File);
         Trash_Lock : constant Files.File_System.Mutation_Result := Files.File_System.Move_To_Trash (Locked_Dir);
      begin
         Assert (Trash_Keep.Success and then Trash_Lock.Success, "partial-empty setup trashes both entries");
      end;

      --  Strip all permissions from the trashed directory so its child cannot be
      --  removed, forcing that one entry's purge to fail while the file succeeds.
      Assert
        (Files.File_System.Set_Permissions (Trashed_Lock, 8#000#).Success,
         "partial-empty setup locks the trashed directory");

      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Assert (Load.Success, "partial-empty setup loads the trash view");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Assert (Files.Model.Item_Count (Model) = 2, "the trash view lists both trashed entries");

      --  Emptying must never crash; the ordinary file is always removed.
      Result := Files.Controller.Execute_Command (Files.Commands.Empty_Trash_Command, Model, Settings);
      Assert
        (Result.Operation.Status in Files.Operations.Operation_Success | Files.Operations.Operation_Failed,
         "empty trash returns a defined status without crashing");
      Assert (not Ada.Directories.Exists (Join (Trash_File, "purge-me.txt")), "the removable payload is purged");
      Assert
        (not Ada.Directories.Exists (Join (Trash_Info, "purge-me.txt.trashinfo")),
         "the removable payload's sidecar is purged");

      --  When the lock actually held (non-root), the survivor is reported through
      --  the non-fatal partial diagnostic while the overall result stays success.
      if Ada.Directories.Exists (Trashed_Lock) then
         Assert (Result.Operation.Status = Files.Operations.Operation_Success, "a partial empty still reports success");
         Assert
           (Files.Model.Last_Error_Key (Model) = "error.trash.empty_partial",
            "a partial empty records the partial diagnostic");
         Assert (Files.Model.Item_Count (Model) = 1, "the un-removable entry remains in the reloaded trash view");
      end if;

      --  Unlock and remove the fixture tree.
      declare
         Unlocked : constant Files.File_System.Mutation_Result :=
           Files.File_System.Set_Permissions (Trashed_Lock, 8#755#);
         pragma Unreferenced (Unlocked);
      begin
         null;
      end;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Empty_Trash_Partial_Failure;
