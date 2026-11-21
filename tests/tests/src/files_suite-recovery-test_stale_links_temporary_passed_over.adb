separate (Files_Suite.Recovery)
   --  A helper stopped while it saved a copy journal leaves its links.tmp
   --  behind. The next save passes over it: the journal is written, the
   --  leftover is neither followed nor removed, and the save leaves no
   --  temporary of its own.
   procedure Test_Stale_Links_Temporary_Passed_Over (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Batch    : constant Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Borrow (Root);
      Expected : Files.Types.String_Vectors.Vector;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "links.tmp"), "half a journal");
      Expected.Append (To_Unbounded_String ("source-token"));
      Expected.Append (To_Unbounded_String ("destination-token"));
      Files.Jobs.Copy_Context.Save (Batch, Expected);
      Assert (Files.Jobs.Copy_Context.Records (Batch) = Expected, "the journal is saved past the leftover");
      Assert (File_Is (Join (Root, "links.tmp"), "half a journal"), "the leftover is left as it was");
      Assert (not Ada.Directories.Exists (Join (Root, "links.tmp-2")), "and the save's own temporary is gone");
      Expected.Append (To_Unbounded_String ("another-token"));
      Files.Jobs.Copy_Context.Save (Batch, Expected);
      Assert (Files.Jobs.Copy_Context.Records (Batch) = Expected, "and so is every later save");
      Reset_Root;
   end Test_Stale_Links_Temporary_Passed_Over;
