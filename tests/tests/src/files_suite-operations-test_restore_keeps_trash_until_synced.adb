with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   --  A restore from a trash on another device copies the item back. When
   --  that copy cannot be synced, the trash keeps its copy and its info
   --  file, so the item is still listed there rather than gone from both.
   procedure Test_Restore_Keeps_Trash_Until_Synced (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote      : Files_Suite.Volumes.Remote_Directory;
      Original    : constant String := Join (Root, "restore-synced.txt");
      Trashed     : Files.Types.UString;
      Result      : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip
           ("Test_Restore_Keeps_Trash_Until_Synced", "the sync fault hooks fsync in Linux-only C");
         return;
      end if;
      Reset_Root;
      Remote.Create ("files-test-restore-sync-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Restore_Keeps_Trash_Until_Synced", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TEST_SYNC_FAULT_SUFFIX");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Remote.Path, "data"));
      Write_Binary_File (Original, "kept");
      Result := Files.File_System.Move_To_Trash (Original, Trashed);
      Assert (Result.Success and then not Ada.Directories.Exists (Original),
              "the item goes to a trash on another device");
      declare
         Info : constant String :=
           Join (Join (Join (Join (Remote.Path, "data"), "Trash"), "info"),
                 Ada.Directories.Simple_Name (To_String (Trashed)) & ".trashinfo");
      begin
         Ada.Environment_Variables.Set ("FILES_TEST_SYNC_FAULT_SUFFIX", "/restore-synced.txt");
         Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
         Ada.Environment_Variables.Clear ("FILES_TEST_SYNC_FAULT_SUFFIX");
         Assert (Result.Success and then File_Has_Bytes (Original, "kept"), "the item is restored");
         Assert (File_Has_Bytes (To_String (Trashed), "kept"), "an unsynced restore keeps the trash's copy");
         Assert (Ada.Directories.Exists (Info), "and its info file, so the trash still lists it");
      end;
   end Test_Restore_Keeps_Trash_Until_Synced;
