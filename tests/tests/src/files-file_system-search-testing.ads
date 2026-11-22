--  What the suite reaches of Files.File_System.Search that is not part of its interface.
package Files.File_System.Search.Testing is

   --  Whether Bytes, text and not binary, contain Query, ignoring case.
   --  UTF-16 and Windows-1252 text is searched as what it says
   --  (Files.Text_Encoding.Searchable_Text).
   --
   --  @param Bytes A file's first bytes.
   --  @param Query Text to look for; "" matches nothing.
   --  @return True for a text match.
   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean;

end Files.File_System.Search.Testing;
