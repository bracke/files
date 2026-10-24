separate (Files_Suite.Operations)
   procedure Test_Released_Recovery_Goes_To_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest       : constant String := Join (Root, "replaced.txt");
      Trash_Home : constant String := Root & "_release_xdg";
      Trashed    : constant String := Join (Join (Join (Trash_Home, "Trash"), "files"), "replaced.txt");
      Had_Back   : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Back   : constant String := Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND", "");
      Had_Xdg    : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Old_Xdg    : constant String := Ada.Environment_Variables.Value ("XDG_DATA_HOME", "");
      Backup     : Files.Types.UString;
      Result     : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
      end Restore_Environment;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip
           ("Test_Released_Recovery_Goes_To_Trash",
            "Hostkit.Host.Current /= Hostkit.Host.Linux");
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
      Assert (Project_Tools.Files.Read_Raw_File (Trashed) = "original",
              "the trash holds the original under its own name");
      Assert (not Ada.Directories.Exists (Ada.Directories.Containing_Directory (To_String (Backup))),
              "the hidden recovery folder is gone");
      Restore_Environment;
      Project_Tools.Files.Delete_Tree (Trash_Home);
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Released_Recovery_Goes_To_Trash;
