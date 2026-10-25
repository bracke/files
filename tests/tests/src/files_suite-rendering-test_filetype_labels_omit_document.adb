separate (Files_Suite.Rendering)
   --  The detail-view type labels are the short format names, without the
   --  redundant "document" word that widened the Type column.
   procedure Test_Filetype_Labels_Omit_Document (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("info.kind.markdown"),
         "Markdown",
         "the markdown type label omits 'document'");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("info.kind.document.pdf"),
         "PDF",
         "the PDF type label omits 'document'");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("info.kind.document.word"),
         "Word",
         "the Word type label omits 'document'");
      Assert (Files.Localization.Text ("info.kind.document.spreadsheet")'Length > 0,
              "the spreadsheet type label is present");
   end Test_Filetype_Labels_Omit_Document;
