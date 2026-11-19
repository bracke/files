with Files.Extra_Info;
with Files.Types;

--  What an item's content says about it, sniffed from the item itself for
--  the info pane: a folder's entry count, a text file's lines and encoding,
--  an image's dimensions, a PDF's pages, an archive's entries, an
--  executable's format, a link's target. Every read is bounded. The parent
--  answers Extra_Info_Of through this child. A private child.
private package Files.File_System.Content_Info is

   --  As Files.File_System.Extra_Info_Of.
   --
   --  @param Path Full path of the item.
   --  @param Kind Item kind.
   --  @param Filetype Detected filetype (MIME-style) of the item.
   --  @param Show_Hidden Whether a folder's count includes hidden entries.
   --  @return The extra info, or No_Info when there is none for the item.
   function Extra_Info_Of
     (Path        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String;
      Show_Hidden : Boolean := True)
      return Files.Extra_Info.Info;

end Files.File_System.Content_Info;
