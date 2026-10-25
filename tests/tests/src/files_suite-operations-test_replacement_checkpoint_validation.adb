separate (Files_Suite.Operations)
   procedure Test_Replacement_Checkpoint_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      File : Ada.Streams.Stream_IO.File_Type;
      Replacement_Backup : constant String := Join (Root, "replacement-backup");
      Replacement_Record : constant String := Join (Root, "replacement-record");
      Replacement_Target : constant String := Join (Root, "replacement-target");

      procedure Write_Replacement_Record (Record_Path : String) is
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Record_Path);
         String'Output
           (Ada.Streams.Stream_IO.Stream (File), Replacement_Backup);
         String'Output
           (Ada.Streams.Stream_IO.Stream (File),
            Files.File_Identities.Token (Replacement_Backup));
         Ada.Streams.Stream_IO.Close (File);
      end Write_Replacement_Record;
   begin
      Reset_Root;
      Write_Binary_File (Replacement_Backup, "preserved destination");
      Write_Replacement_Record (Replacement_Record);
      Assert
        (Files.Transfer_Jobs.Testing.Replacement_Checkpoint_Is_Valid
           (Replacement_Record),
         "a complete replacement checkpoint with a live identity is accepted");
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.Append_File, Replacement_Record);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), True);
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (not Files.Transfer_Jobs.Testing.Replacement_Checkpoint_Is_Valid
           (Replacement_Record),
         "a replacement checkpoint rejects trailing fields");

      Write_Replacement_Record (Replacement_Target);
      Ada.Directories.Delete_File (Replacement_Record);
      if Hostkit.Fs.Create_Link (Replacement_Target, Replacement_Record) then
         Assert
           (not Files.Transfer_Jobs.Testing.Replacement_Checkpoint_Is_Valid
              (Replacement_Record),
            "replacement recovery refuses a symlink checkpoint");
         declare
            Removed : constant Boolean :=
              Hostkit.Fs.Delete_Link (Replacement_Record);
            pragma Unreferenced (Removed);
         begin
            null;
         end;
      else
         Files_Suite.Support.Link_Not_Made
           ("Test_Replacement_Checkpoint_Validation",
            Files_Suite.Support.Symbolic_Link);
      end if;
      if Hostkit.Fs.Create_Hard_Link
        (Replacement_Target, Replacement_Record)
      then
         Assert
           (not Files.Transfer_Jobs.Testing.Replacement_Checkpoint_Is_Valid
              (Replacement_Record),
            "replacement recovery refuses a multiply-linked checkpoint");
         Ada.Directories.Delete_File (Replacement_Record);
      else
         Files_Suite.Support.Link_Not_Made ("Test_Replacement_Checkpoint_Validation", Files_Suite.Support.Hard_Link);
      end if;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Replacement_Checkpoint_Validation;
