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
      --  Restores what the test changes, on failure too.
      Environment  : Files_Suite.Support.Environment_Guard;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;

      --  Re-open the locked payload so the fixture tree can be removed.
      procedure Unlock_Payload is
         Unlocked : constant Files.File_System.Mutation_Result :=
           Files.File_System.Set_Permissions (Trashed_Lock, 8#755#);
         pragma Unreferenced (Unlocked);
      begin
         null;
      end Unlock_Payload;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");

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
         Assert (Trash_Keep.Success, "partial-empty setup trashes both entries: the file");
         Assert (Trash_Lock.Success, "partial-empty setup trashes both entries: the directory");
      end;

      --  Strip all permissions from the trashed directory so its child cannot be
      --  removed, forcing that one entry's purge to fail while the file succeeds.
      Assert
        (Files.File_System.Set_Permissions (Trashed_Lock, 8#000#).Success,
         "partial-empty setup locks the trashed directory");

      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Assert (Load.Success, "partial-empty setup loads the trash view");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 2, "the trash view lists both trashed entries");

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
         Files_Suite.Support.Assert_Equal
           (Result.Operation.Status,
            Files.Operations.Operation_Success,
            "a partial empty still reports success");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model),
            "error.trash.empty_partial",
            "a partial empty records the partial diagnostic");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Item_Count (Model),
            1,
            "the un-removable entry remains in the reloaded trash view");
      end if;

      --  Unlock and remove the fixture tree.
      Unlock_Payload;
      Project_Tools.Files.Delete_Tree (Trash_Home);
   exception
      when others =>
         Unlock_Payload;
         raise;
   end Test_Empty_Trash_Partial_Failure;
