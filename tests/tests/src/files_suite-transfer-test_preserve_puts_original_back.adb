with Files.File_System.Transfer;
with Files_Suite.Support.Disk;
with Files.File_System.Recovery_Registry;
with Files.IO.Durability.Testing;
with Files_Suite.Support.Guards;
separate (Files_Suite.Transfer)
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
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Write_Binary_File (Dest, "the original");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      --  Syncing the stage once the original has moved into it fails.
      Files.IO.Durability.Testing.Fail_Stage_Sync;
      Result := Files.File_System.Recovery_Registry.Preserve_For_Replace (Dest, Backup);
      Files.IO.Durability.Testing.Clear;
      Assert (not Result.Success, "the preserve reports the failed sync");
      Files_Suite.Support.Assert_Equal (Length (Backup), 0, "no backup is left to recover from");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Dest),
         "the original",
         "the original is back at its own path");
      Files_Suite.Support.Assert_Equal (Stages_Left, 0, "no hidden recovery folder is left behind");

      --  Replacing an entry with itself, spelled through a linked folder, is
      --  not a replace: the source is never moved aside to make room for it.
      declare
         Real    : constant String := Join (Root, "replace-self-real");
         Alias   : constant String := Join (Root, "replace-self-alias");
         Source  : constant String := Join (Real, "self.txt");
         Held    : Natural := 0;
         Replaced, Replaced_Identity, Created_Identity, Created_Revision : Files.Types.UString;

         procedure Note_Held (Backup, Backup_Identity : String) is
            pragma Unreferenced (Backup, Backup_Identity);
         begin
            Held := Held + 1;
         end Note_Held;
      begin
         Ada.Directories.Create_Directory (Real);
         Write_Binary_File (Source, "itself");
         if Files_Suite.Support.Disk.Create_Symlink (Real, Alias) then
            Result := Files.File_System.Transfer.Import_Replacing
              (Source, Join (Alias, "self.txt"), Files.File_System.Drop_Copy, Replace => True,
               Replaced => Replaced, Replaced_Identity => Replaced_Identity,
               Created_Identity => Created_Identity, Created_Tree_Revision => Created_Revision,
               Preserved => Note_Held'Access);
            Assert (not Result.Success, "copying an entry onto itself is refused");
            Files_Suite.Support.Assert_Equal (Held, 0, "the entry is never moved aside for itself");
            Files_Suite.Support.Assert_Equal (Project_Tools.Files.Read_Raw_File (Source), "itself", "and stays");
            declare
               Removed : constant Boolean := Hostkit.Fs.Delete_Link (Alias);
               pragma Unreferenced (Removed);
            begin
               null;
            end;
         else
            Files_Suite.Support.Disk.Link_Not_Made
              ("Test_Preserve_Puts_Original_Back", Files_Suite.Support.Disk.Symbolic_Link);
         end if;
      end;
   exception
      when others =>
         Files.IO.Durability.Testing.Clear;
         raise;
   end Test_Preserve_Puts_Original_Back;
