separate (Files_Suite.Operations)
   --  Undo's restore names the item it trashed, and then moves it the way a
   --  plain restore does: something else now under that trash name stays.
   procedure Test_Restore_Checks_Trashed_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home  : constant String := Root & "_restore_identity_xdg";
      Source      : constant String := Join (Root, "named.txt");
      Trashed     : Files.Types.UString;
      Result      : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      Write_File (Source, "first");
      declare
         Identity : constant String := Files.File_Identities.Token (Source);
      begin
         Result := Files.File_System.Move_To_Trash (Source, Trashed);
         Assert (Result.Success, "the item is trashed");
         --  Another file now holds the trash name.
         Ada.Directories.Delete_File (To_String (Trashed));
         Write_File (To_String (Trashed), "someone else");
         Result := Files.File_System.Restore_From_Trash (To_String (Trashed), Expected_Identity => Identity);
         Assert (not Result.Success, "a different item under the trash name is not restored for undo");
         Assert (not Ada.Directories.Exists (Source), "nothing lands at the original path");
         Assert (File_Has_Bytes (To_String (Trashed), "someone else"), "the other item stays in the trash");
      end;
      Result := Files.File_System.Restore_From_Trash
        (To_String (Trashed), Expected_Identity => Files.File_Identities.Token (To_String (Trashed)));
      Assert (Result.Success, "the item undo names is restored");
      Assert (File_Has_Bytes (Source, "someone else"), "it is back at the original path");
      Assert (not Ada.Directories.Exists (To_String (Trashed)), "and gone from the trash");
      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Restore_Checks_Trashed_Identity;
