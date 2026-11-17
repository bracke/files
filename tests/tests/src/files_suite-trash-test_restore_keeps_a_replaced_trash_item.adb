with Files.File_System.Trash;
with Files.File_System.Testing;
with Files_Suite.Volumes;
with Files_Suite.Support.Guards;
separate (Files_Suite.Trash)
   --  A restore from a trash on another device copies the item back, then
   --  removes the trash copy. If the trash was emptied and another item
   --  trashed under the same name meanwhile, that other item is not the one
   --  restored: it stays in the trash with its info file.
   procedure Test_Restore_Keeps_A_Replaced_Trash_Item (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote      : Files_Suite.Volumes.Remote_Directory;
      Original    : constant String := Join (Root, "restore-replaced.txt");
      Trashed     : Files.Types.UString;
      Result      : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Reset_Root;
      Remote.Create ("files-test-restore-replaced-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Restore_Keeps_A_Replaced_Trash_Item", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Guards.Save (Environment, "XDG_DATA_HOME");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Remote.Path, "data"));
      Write_Binary_File (Original, "restored");
      Result := Files.File_System.Trash.Move_To_Trash (Original, Trashed);
      Assert (Result.Success and then not Ada.Directories.Exists (Original),
              "the item goes to a trash on another device");
      declare
         Info : constant String :=
           Join (Join (Join (Join (Remote.Path, "data"), "Trash"), "info"),
                 Ada.Directories.Simple_Name (To_String (Trashed)) & ".trashinfo");
      begin
         Files.File_System.Testing.Change_Trashed_After_Copy;
         Result := Files.File_System.Trash.Restore_From_Trash (To_String (Trashed));
         Files.File_System.Testing.Stop_Changing_Trashed;
         Assert (Result.Success, "the restore itself succeeds");
         Assert (File_Has_Bytes (Original, "restored"), "the item is back where it was");
         Assert (File_Has_Bytes (To_String (Trashed), "another item"),
                 "the item trashed under the same name since stays in the trash");
         Assert (Ada.Directories.Exists (Info), "and its info file stays with it");
      end;
   exception
      when others =>
         Files.File_System.Testing.Stop_Changing_Trashed;
         raise;
   end Test_Restore_Keeps_A_Replaced_Trash_Item;
