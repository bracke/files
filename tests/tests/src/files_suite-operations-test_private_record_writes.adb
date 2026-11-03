with Ada.Streams;
with Files.Durable_Writes;
with Files.History_Journal;
separate (Files_Suite.Operations)
   --  Durable_Writes.Write_Private_File, under the history journal, the job
   --  records and the copy links: the file is owner-only where the host has
   --  mode bits (the journal lists every path the user touched), an entry
   --  already there is refused and kept, a writer that fails leaves nothing,
   --  and Remove_Owned removes only the file it made.
   procedure Test_Private_Record_Writes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Temporary : constant String := Join (Root, "record.tmp");
      Identity  : Unbounded_String;
      Raised    : Boolean;

      procedure Write_Text (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Write (Stream, "record");
      end Write_Text;

      procedure Write_Fails (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Write (Stream, "part");
         raise Program_Error;
      end Write_Fails;

      function Owner_Only (Path : String) return Boolean is
         Known : Boolean;
         Bits  : constant Natural := Hostkit.Metadata.File_Permission_Bits (Path, Known);
      begin
         return not Hostkit.Metadata.Mode_Bits_Are_Native or else (Known and then Bits mod 8#100# = 0);
      end Owner_Only;
   begin
      Reset_Root;
      Files.Durable_Writes.Write_Private_File (Temporary, Write_Text'Access, Identity);
      Assert (File_Is (Temporary, "record"), "the record is written");
      Assert (Length (Identity) > 0, "and its identity returned");
      Assert (Owner_Only (Temporary), "and nobody but its owner can read it");

      Raised := False;
      declare
         Again : Unbounded_String;
      begin
         Files.Durable_Writes.Write_Private_File (Temporary, Write_Text'Access, Again);
      exception
         when others =>
            Raised := True;
      end;
      Assert (Raised and then File_Is (Temporary, "record"), "an entry already there is refused, and kept");

      Files.Durable_Writes.Remove_Owned (Temporary, "not-its-identity");
      Assert (Ada.Directories.Exists (Temporary), "Remove_Owned keeps a file it did not make");
      Files.Durable_Writes.Remove_Owned (Temporary, To_String (Identity));
      Assert (not Ada.Directories.Exists (Temporary), "and removes the one it did");

      Raised := False;
      begin
         Files.Durable_Writes.Write_Private_File (Temporary, Write_Fails'Access, Identity);
      exception
         when others =>
            Raised := True;
      end;
      Assert (Raised and then not Ada.Directories.Exists (Temporary), "a writer that fails leaves nothing behind");

      --  The history journal itself.
      Files.History_Journal.Save_Stacks
        (Root, Files.Model.Undo_Entry_Vectors.Empty_Vector, Files.Model.Undo_Entry_Vectors.Empty_Vector,
         Required => True);
      Assert (Ada.Directories.Exists (Join (Root, "history")), "the history journal is written");
      Assert (Owner_Only (Join (Root, "history")), "owner-only");
   end Test_Private_Record_Writes;
