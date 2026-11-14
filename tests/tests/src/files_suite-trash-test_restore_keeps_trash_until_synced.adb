with Files.Durability.Testing;
with Files_Suite.Volumes;
separate (Files_Suite.Trash)
   --  A restore from a trash on another device copies the item back. When
   --  that copy cannot be put on the device, the restore does not happen:
   --  the trash keeps its copy and its info file, and still lists it.
   procedure Test_Restore_Keeps_Trash_Until_Synced (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote      : Files_Suite.Volumes.Remote_Directory;
      Original    : constant String := Join (Root, "restore-synced.txt");
      Trashed     : Files.Types.UString;
      Result      : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Reset_Root;
      Remote.Create ("files-test-restore-sync-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Restore_Keeps_Trash_Until_Synced", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
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
         --  The restored file is flushed as it is written, staged as "payload".
         Files.Durability.Testing.Fail_Syncs_Ending_With ("/payload");
         Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
         Files.Durability.Testing.Clear;
         --  The copy is flushed as it is written, so a flush that fails
         --  fails the restore before anything is published.
         Assert (not Result.Success and then not Ada.Directories.Exists (Original),
                 "a restore whose copy cannot be put on the device does not happen");
         Assert (File_Has_Bytes (To_String (Trashed), "kept"), "the trash keeps its copy");
         Assert (Ada.Directories.Exists (Info), "and its info file, so the trash still lists it");
      end;
   exception
      when others =>
         Files.Durability.Testing.Clear;
         raise;
   end Test_Restore_Keeps_Trash_Until_Synced;
