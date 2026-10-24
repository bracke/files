separate (Files_Suite.Operations)
   procedure Test_Preserve_Puts_Original_Back (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest     : constant String := Join (Root, "original.txt");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Back : constant String := Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND", "");
      Backup   : Files.Types.UString;
      Result   : Files.File_System.Mutation_Result;

      function Stages_Left return Natural is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
         Count  : Natural := 0;
      begin
         Ada.Directories.Start_Search
           (Search, Root, ".files-recovery-*", [Ada.Directories.Directory => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Count := Count + 1;
         end loop;
         Ada.Directories.End_Search (Search);
         return Count;
      end Stages_Left;

      procedure Restore_Environment is
      begin
         Ada.Environment_Variables.Clear ("FILES_TEST_STAGE_SYNC_FAULT");
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Preserve_Puts_Original_Back", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Reset_Root;
      Write_Binary_File (Dest, "the original");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Ada.Environment_Variables.Set ("FILES_TEST_STAGE_SYNC_FAULT", "1");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Ada.Environment_Variables.Clear ("FILES_TEST_STAGE_SYNC_FAULT");
      Assert (not Result.Success, "the preserve reports the failed sync");
      Assert (Length (Backup) = 0, "no backup is left to recover from");
      Assert (Project_Tools.Files.Read_Raw_File (Dest) = "the original", "the original is back at its own path");
      Assert (Stages_Left = 0, "no hidden recovery folder is left behind");
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Preserve_Puts_Original_Back;
