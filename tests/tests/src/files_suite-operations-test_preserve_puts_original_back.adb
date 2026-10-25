separate (Files_Suite.Operations)
   procedure Test_Preserve_Puts_Original_Back (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest     : constant String := Join (Root, "original.txt");
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

      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Preserve_Puts_Original_Back", "needs Linux");
         return;
      end if;
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Save (Environment, "FILES_TEST_STAGE_SYNC_FAULT");
      Reset_Root;
      Write_Binary_File (Dest, "the original");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Ada.Environment_Variables.Set ("FILES_TEST_STAGE_SYNC_FAULT", "1");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Ada.Environment_Variables.Clear ("FILES_TEST_STAGE_SYNC_FAULT");
      Assert (not Result.Success, "the preserve reports the failed sync");
      Files_Suite.Support.Assert_Equal (Length (Backup), 0, "no backup is left to recover from");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Dest),
         "the original",
         "the original is back at its own path");
      Files_Suite.Support.Assert_Equal (Stages_Left, 0, "no hidden recovery folder is left behind");
   end Test_Preserve_Puts_Original_Back;
