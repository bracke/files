with Files.Extra_Info;
separate (Files_Suite.Info)
   procedure Test_Extra_Counts_Mark_Capped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  The readers' limits: 20_000 lines, 8 MiB scanned.
      Line_Limit : constant := 20_000;
      Byte_Limit : constant := 8_388_608;

      --  Lines lines of one character each.
      function Lines (Count : Natural) return String is
         Text : String (1 .. 2 * Count);
      begin
         for Index in 1 .. Count loop
            Text (2 * Index - 1) := 'x';
            Text (2 * Index) := ASCII.LF;
         end loop;
         return Text;
      end Lines;

      function Extra_Of (Path, Filetype : String) return Files.Extra_Info.Info is
        (Files.File_System.Extra_Info_Of (Path, Files.Types.Regular_File_Item, Filetype));

      At_Limit   : constant String := Join (Root, "at-limit.txt");
      Over_Limit : constant String := Join (Root, "over-limit.txt");
      Long_Pdf   : constant String := Join (Root, "long.pdf");
      Full_Pdf   : constant String := Join (Root, "full.pdf");
      Page       : constant String := "1 0 obj <</Type/Page>> endobj";
      Extra      : Files.Extra_Info.Info;
   begin
      Reset_Root;
      Write_Binary_File (At_Limit, Lines (Line_Limit));
      Write_Binary_File (Over_Limit, Lines (Line_Limit + 1));

      Extra := Extra_Of (At_Limit, "text/plain");
      Files_Suite.Support.Assert_Equal (Extra.Count, Line_Limit, "a file of exactly the limit counts every line");
      Assert (not Extra.Capped, "a count that reached the end of the file is exact");
      Extra := Extra_Of (Over_Limit, "text/plain");
      Files_Suite.Support.Assert_Equal (Extra.Count, Line_Limit, "the line count stops at its limit");
      Assert (Extra.Capped, "a line count stopped at its limit is marked capped");

      --  A page past the scan limit is not reached, and the count says so.
      Write_Filler_File (Long_Pdf, ' ', Byte_Limit, Page);
      Extra := Extra_Of (Long_Pdf, "application/pdf");
      Files_Suite.Support.Assert_Equal
        (Files_Suite.Support.Describe (Extra), "document.pdf.pages|0+", "a PDF longer than the scan limit is capped");
      Ada.Directories.Delete_File (Long_Pdf);
      --  One ending exactly at the limit is read whole.
      Write_Filler_File (Full_Pdf, ' ', Byte_Limit - Page'Length, Page);
      Extra := Extra_Of (Full_Pdf, "application/pdf");
      Files_Suite.Support.Assert_Equal
        (Files_Suite.Support.Describe (Extra), "document.pdf.pages|1", "a PDF read to its end is exact");
      Ada.Directories.Delete_File (Full_Pdf);
   end Test_Extra_Counts_Mark_Capped;
