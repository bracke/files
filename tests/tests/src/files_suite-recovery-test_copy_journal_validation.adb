with Files.File_System.Testing;
with Files.File_System.Transfer;
with Files_Suite.Support.Disk;
separate (Files_Suite.Recovery)
   procedure Test_Copy_Journal_Validation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Batch    : constant Files.Jobs.Copy_Context.Session :=
        Files.Jobs.Copy_Context.Borrow (Root);
      Expected : Files.Types.String_Vectors.Vector;
      Actual   : Files.Types.String_Vectors.Vector;
      File     : Ada.Streams.Stream_IO.File_Type;
      Rejected : Boolean := False;
      Victim   : constant String := Join (Root, "copy-journal-victim");
      Source   : constant String := Join (Root, "copy-journal-source");
      Target   : constant String := Join (Root, "copy-journal-target");
      Result   : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      begin
         declare
            Invalid : constant Files.Jobs.Copy_Context.Session :=
              Files.Jobs.Copy_Context.Borrow ("relative-copy-batch");
            pragma Unreferenced (Invalid);
         begin
            null;
         end;
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Assert (Rejected, "copy journals reject a relative borrowed directory");
      Rejected := False;
      begin
         declare
            Invalid : constant Files.Jobs.Copy_Context.Session :=
              Files.Jobs.Copy_Context.Borrow
                (Root & Character'Val (0) & "copy-batch");
            pragma Unreferenced (Invalid);
         begin
            null;
         end;
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Assert (Rejected, "copy journals reject a NUL-containing borrowed directory");
      Rejected := False;

      Expected.Append (To_Unbounded_String ("source-token"));
      Expected.Append (To_Unbounded_String ("destination-token"));
      Files.Jobs.Copy_Context.Save (Batch, Expected);
      Actual := Files.Jobs.Copy_Context.Records (Batch);
      Assert (Actual = Expected, "a complete copy journal round-trips");

      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.Append_File, Join (Root, "links"));
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), True);
      Ada.Streams.Stream_IO.Close (File);
      begin
         Actual := Files.Jobs.Copy_Context.Records (Batch);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert (Rejected, "copy journals reject trailing bytes");

      Ada.Directories.Delete_File (Join (Root, "links"));
      Write_Binary_File (Victim, "protected copy journal");
      if Hostkit.Fs.Create_Hard_Link (Victim, Join (Root, "links")) then
         Rejected := False;
         begin
            Actual := Files.Jobs.Copy_Context.Records (Batch);
         exception
            when Ada.IO_Exceptions.Data_Error => Rejected := True;
         end;
         Assert
           (Rejected
            and then File_Is (Victim, "protected copy journal"),
            "copy journal reads refuse a multiply-linked file");
         Ada.Directories.Delete_File (Join (Root, "links"));
      else
         Files_Suite.Support.Disk.Link_Not_Made ("Test_Copy_Journal_Validation", Files_Suite.Support.Disk.Hard_Link);
      end if;

      Expected.Clear;
      Expected.Append (To_Unbounded_String ("source-token"));
      Expected.Append (To_Unbounded_String ("source-revision"));
      Expected.Append (To_Unbounded_String ("source-digest"));
      Expected.Append (To_Unbounded_String ("relative-destination"));
      Expected.Append (To_Unbounded_String ("destination-token"));
      Expected.Append (To_Unbounded_String ("destination-revision"));
      Files.Jobs.Copy_Context.Save (Batch, Expected);
      Write_Binary_File (Source, "copy me");
      Result := Files.File_System.Transfer.Copy_Tree (Source, Target, Batch);
      Assert
        (not Result.Success and then not Ada.Directories.Exists (Target),
         "copy journals reject relative persisted hard-link paths before copying");

      if Hostkit.Fs.Create_Link (Victim, Join (Root, "links.tmp")) then
         Write_Binary_File (Victim, "preserve me");
         Files.Jobs.Copy_Context.Save (Batch, Expected);
         Assert
           (File_Is (Victim, "preserve me")
            and then Hostkit.Fs.Is_Link (Join (Root, "links.tmp"))
            and then Files.Jobs.Copy_Context.Records (Batch) = Expected,
            "copy journals pass over a temporary symlink without truncating its target");
         declare
            Removed : constant Boolean :=
              Hostkit.Fs.Delete_Link (Join (Root, "links.tmp"));
            pragma Unreferenced (Removed);
         begin
            null;
         end;
      else
         Files_Suite.Support.Disk.Link_Not_Made ("Test_Copy_Journal_Validation",
                                                 Files_Suite.Support.Disk.Symbolic_Link);
      end if;

      --  A hard-linked file whose copy the destination then refuses (an entry
      --  appeared there while it was staged) is not journalled: a later link
      --  to the same file in the batch must be copied, not checked against a
      --  destination that holds something else.
      declare
         Linked  : constant String := Join (Root, "journal-linked");
         Twin    : constant String := Join (Root, "journal-linked-twin");
         Refused : constant String := Join (Root, "journal-refused-copy");
      begin
         if Ada.Directories.Exists (Join (Root, "links")) then
            Ada.Directories.Delete_File (Join (Root, "links"));
         end if;
         Write_Binary_File (Linked, "linked bytes");
         if Hostkit.Fs.Create_Hard_Link (Linked, Twin) then
            Files.File_System.Testing.Change_Source_After_Copy
              (Root, Refused, Files.File_System.Testing.Edit_Source);
            Result := Files.File_System.Transfer.Copy_Tree (Linked, Refused, Batch);
            Files.File_System.Testing.Stop_Changing_Source;
            Assert (not Result.Success, "a copy whose destination appeared meanwhile is refused");
            Assert
              (Files.Jobs.Copy_Context.Records (Batch).Is_Empty,
               "and its hard link is not journalled for the rest of the batch");
         else
            Files_Suite.Support.Disk.Link_Not_Made ("Test_Copy_Journal_Validation", Files_Suite.Support.Disk.Hard_Link);
         end if;
      end;

      --  A batch copies two names of one inode: the second is linked to the
      --  first copy. When that copy was edited meanwhile (a retried batch,
      --  its copy published and changed), the second gets a copy of its own
      --  from the source instead of failing: never a link to the edited one.
      declare
         Folder  : constant String := Join (Root, "copy-journal-edited");
         Shared  : constant Files.Jobs.Copy_Context.Session :=
           Files.Jobs.Copy_Context.Borrow (Folder);
         First   : constant String := Join (Folder, "first");
         Second  : constant String := Join (Folder, "second");
         First_Copy  : constant String := Join (Folder, "first-copy");
         Second_Copy : constant String := Join (Folder, "second-copy");
      begin
         Ada.Directories.Create_Directory (Folder);
         Write_Binary_File (First, "shared bytes");
         if Hostkit.Fs.Create_Hard_Link (First, Second) then
            Result := Files.File_System.Transfer.Copy_Tree (First, First_Copy, Shared);
            Assert (Result.Success, "the first name is copied");
            Write_Binary_File (First_Copy, "edited byte!");
            Result := Files.File_System.Transfer.Copy_Tree (Second, Second_Copy, Shared);
            Assert (Result.Success, "the second name is copied past the edited first copy");
            Assert (File_Is (Second_Copy, "shared bytes") and then File_Is (First_Copy, "edited byte!"),
                    "with the source's bytes, the edit left where it was made");
            Assert (Files.File_Identities.Token (Second_Copy) /= Files.File_Identities.Token (First_Copy),
                    "as a file of its own");
         else
            Files_Suite.Support.Disk.Link_Not_Made ("Test_Copy_Journal_Validation", Files_Suite.Support.Disk.Hard_Link);
         end if;
      end;
   exception
      when others =>
         Files.File_System.Testing.Stop_Changing_Source;
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Copy_Journal_Validation;
