separate (Files_Suite.Operations)
   procedure Test_Copy_Journal_Validation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Batch    : constant Files.Copy_Context.Session :=
        Files.Copy_Context.Borrow (Root);
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
            Invalid : constant Files.Copy_Context.Session :=
              Files.Copy_Context.Borrow ("relative-copy-batch");
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
            Invalid : constant Files.Copy_Context.Session :=
              Files.Copy_Context.Borrow
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
      Files.Copy_Context.Save (Batch, Expected);
      Actual := Files.Copy_Context.Records (Batch);
      Assert (Actual = Expected, "a complete copy journal round-trips");

      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.Append_File, Join (Root, "links"));
      Boolean'Output (Ada.Streams.Stream_IO.Stream (File), True);
      Ada.Streams.Stream_IO.Close (File);
      begin
         Actual := Files.Copy_Context.Records (Batch);
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Assert (Rejected, "copy journals reject trailing bytes");

      Ada.Directories.Delete_File (Join (Root, "links"));
      Write_Binary_File (Victim, "protected copy journal");
      if Hostkit.Fs.Create_Hard_Link (Victim, Join (Root, "links")) then
         Rejected := False;
         begin
            Actual := Files.Copy_Context.Records (Batch);
         exception
            when Ada.IO_Exceptions.Data_Error => Rejected := True;
         end;
         Assert
           (Rejected
            and then File_Has_Bytes (Victim, "protected copy journal"),
            "copy journal reads refuse a multiply-linked file");
         Ada.Directories.Delete_File (Join (Root, "links"));
      else
         Files_Suite.Support.Link_Not_Made ("Test_Copy_Journal_Validation", Files_Suite.Support.Hard_Link);
      end if;

      Expected.Clear;
      Expected.Append (To_Unbounded_String ("source-token"));
      Expected.Append (To_Unbounded_String ("source-revision"));
      Expected.Append (To_Unbounded_String ("source-digest"));
      Expected.Append (To_Unbounded_String ("relative-destination"));
      Expected.Append (To_Unbounded_String ("destination-token"));
      Expected.Append (To_Unbounded_String ("destination-revision"));
      Files.Copy_Context.Save (Batch, Expected);
      Write_Binary_File (Source, "copy me");
      Result := Files.File_System.Copy_Tree (Source, Target, Batch);
      Assert
        (not Result.Success and then not Ada.Directories.Exists (Target),
         "copy journals reject relative persisted hard-link paths before copying");

      if Hostkit.Fs.Create_Link (Victim, Join (Root, "links.tmp")) then
         Write_Binary_File (Victim, "preserve me");
         Rejected := False;
         begin
            Files.Copy_Context.Save (Batch, Expected);
         exception
            when Ada.Directories.Use_Error => Rejected := True;
         end;
         Assert
           (Rejected and then File_Has_Bytes (Victim, "preserve me"),
            "copy journals refuse a temporary symlink without truncating its target");
         declare
            Removed : constant Boolean :=
              Hostkit.Fs.Delete_Link (Join (Root, "links.tmp"));
            pragma Unreferenced (Removed);
         begin
            null;
         end;
      else
         Files_Suite.Support.Link_Not_Made ("Test_Copy_Journal_Validation", Files_Suite.Support.Symbolic_Link);
      end if;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Copy_Journal_Validation;
