separate (Files_Suite.Info)
   procedure Test_Pdf_Page_Markers_Any_Spacing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  Write Content as a PDF and describe its page count.
      function Pages_Of (Name : String; Content : String) return String is
         Path : constant String := Join (Root, Name);
      begin
         Write_Binary_File (Path, "%PDF-1.7" & ASCII.LF & Content);
         return Files_Suite.Support.Describe
           (Files.File_System.Extra_Info_Of (Path, Files.Types.Regular_File_Item, "application/pdf"));
      end Pages_Of;
   begin
      Reset_Root;
      Files_Suite.Support.Assert_Equal
        (Pages_Of ("tight.pdf", "1 0 obj <</Type/Page>> endobj"),
         "document.pdf.pages|1",
         "/Type/Page with no space between the names is a page");
      Files_Suite.Support.Assert_Equal
        (Pages_Of ("spaced.pdf", "1 0 obj <</Type  /Page>> endobj"),
         "document.pdf.pages|1",
         "/Type  /Page with two spaces is a page");
      Files_Suite.Support.Assert_Equal
        (Pages_Of ("broken.pdf", "1 0 obj <</Type" & ASCII.LF & "/Page>> endobj"),
         "document.pdf.pages|1",
         "/Type and /Page on separate lines are a page");
      Files_Suite.Support.Assert_Equal
        (Pages_Of
           ("mixed.pdf",
            "1 0 obj <</Type" & ASCII.CR & ASCII.HT & ASCII.NUL & ASCII.FF & "/Page>> endobj" & ASCII.LF
            & "2 0 obj <</Type /Page /Parent 3 0 R>> endobj" & ASCII.LF
            & "3 0 obj <</Type/Pages /Kids [1 0 R 2 0 R]>> endobj"),
         "document.pdf.pages|2",
         "every PDF white-space may separate the names");
      Files_Suite.Support.Assert_Equal
        (Pages_Of ("tree.pdf", "1 0 obj <</Type/Pages /Count 0>> endobj"),
         "document.pdf.pages|0",
         "/Type/Pages, the page tree, is not a page");
      Files_Suite.Support.Assert_Equal
        (Pages_Of ("other.pdf", "1 0 obj <</TypeX /Page /Typed/Page>> endobj"),
         "document.pdf.pages|0",
         "only the name /Type introduces a page");
      Files_Suite.Support.Assert_Equal
        (Pages_Of ("retyped.pdf", "1 0 obj <</Type /Type/Page>> endobj"),
         "document.pdf.pages|1",
         "a /Type after /Type begins the marker again");
      Files_Suite.Support.Assert_Equal
        (Pages_Of ("ending.pdf", "1 0 obj <</Type/Page"),
         "document.pdf.pages|1",
         "a marker ended by the end of the file counts");
      --  4096-byte reads: the marker straddles the first boundary.
      Files_Suite.Support.Assert_Equal
        (Pages_Of ("split.pdf", String'(1 .. 4083 => ' ') & "<</Type" & ASCII.LF & "/Page>>"),
         "document.pdf.pages|1",
         "a marker split across read buffers counts");
   end Test_Pdf_Page_Markers_Any_Spacing;
