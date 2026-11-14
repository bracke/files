with Files.File_System.Testing;
separate (Files_Suite.Recovery)
   procedure Test_Released_Recovery_Goes_To_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest       : constant String := Join (Root, "replaced.txt");
      Trash_Home : constant String := Root & "_release_xdg";
      Trashed    : constant String := Join (Join (Join (Trash_Home, "Trash"), "files"), "replaced.txt");
      Backup     : Files.Types.UString;
      Result     : Files.File_System.Mutation_Result;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      --  Where the Recycle Bin is reachable (Windows) it is made to refuse,
      --  as an unreachable one would; elsewhere it is unreachable anyway.
      Files.File_System.Testing.Refuse_Native_Trash (True);
      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Write_Binary_File (Dest, "original");
      --  A native backend keeps a replaced original in a private recovery
      --  folder, since that trash cannot restore it programmatically.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "Replace keeps the original as a recovery payload");

      --  That trash refuses here: releasing fails and keeps it.
      Result := Files.File_System.Release_Recovery_Payload (To_String (Backup));
      Assert (not Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "a release the trash refuses leaves the payload recoverable");
      --  A native trash records where an item was trashed from, so the
      --  release trashes it from beside its original; refused, it goes back.
      Assert (not Ada.Directories.Exists (Dest),
              "a refused native release takes the original back from beside its old place");
      --  As after a real Replace: the replacement holds the name, so the
      --  original would go beside it as "replaced 2.txt" -- and come back.
      Write_Binary_File (Dest, "replacement");
      Result := Files.File_System.Release_Recovery_Payload (To_String (Backup));
      Assert (not Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "a refused release beside a replacement keeps the payload recoverable");
      Assert (File_Has_Bytes (Dest, "replacement"), "the replacement is left as it was");
      Assert (not Ada.Directories.Exists (Join (Root, "replaced 2.txt")),
              "no numbered copy of the original is left beside it");
      Ada.Directories.Delete_File (Dest);
      Files.File_System.Testing.Refuse_Native_Trash (False);

      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Result := Files.File_System.Release_Recovery_Payload (To_String (Backup));
      Assert (Result.Success, "a released payload goes to the trash");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Trashed),
         "original",
         "the trash holds the original under its own name");
      Assert (not Ada.Directories.Exists (Ada.Directories.Containing_Directory (To_String (Backup))),
              "the hidden recovery folder is gone");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Trash_Original_Path (Trashed),
         Dest,
         "the trash records where the original lived, not the hidden folder it was kept in");

      Project_Tools.Files.Delete_Tree (Trash_Home);
   exception
      when others =>
         --  The next test gets a trash that takes items.
         Files.File_System.Testing.Refuse_Native_Trash (False);
         raise;
   end Test_Released_Recovery_Goes_To_Trash;
