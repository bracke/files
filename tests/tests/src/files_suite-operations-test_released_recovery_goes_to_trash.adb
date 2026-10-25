separate (Files_Suite.Operations)
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
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip
           ("Test_Released_Recovery_Goes_To_Trash",
            "needs Linux");
         return;
      end if;
      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Write_Binary_File (Dest, "original");
      --  A native backend keeps a replaced original in a private recovery
      --  folder, since that trash cannot restore it programmatically.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "Replace keeps the original as a recovery payload");

      --  That trash is not reachable here: releasing fails and keeps it.
      Result := Files.File_System.Release_Recovery_Payload (To_String (Backup));
      Assert (not Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "a release the trash refuses leaves the payload recoverable");

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

      --  A release stopped after its first move leaves the payload under
      --  release/; the next look at the stage puts it back.
      Write_Binary_File (Dest, "second");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Assert (Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "a second original is kept for recovery");
      declare
         Stage  : constant String := Ada.Directories.Containing_Directory (To_String (Backup));
         Holder : constant String := Join (Stage, "release");
      begin
         Ada.Directories.Create_Directory (Holder);
         Ada.Directories.Rename (To_String (Backup), Join (Holder, "replaced.txt"));
         Assert (Files.File_System.Registered_Recovery_Payloads.Contains (Backup),
                 "an interrupted release is still a registered payload");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (To_String (Backup)),
            "second",
            "the held original is back in its payload slot");
         Assert (not Ada.Directories.Exists (Holder), "the release folder is gone again");
      end;
      Result := Files.File_System.Release_Recovery_Payload (To_String (Backup));
      Assert (Result.Success, "the resumed payload can be released");
      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Released_Recovery_Goes_To_Trash;
