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

   --  The notice a search's answer is shown with, or "".
   --
   --  @param Found A successful search's answer.
   --  @return The notice key, or "".
   function Notice_Of (Found : Recursive_Search_Result) return String;

   --  Search a directory tree recursively for item names matching Query.
   --
   --  @param Root_Path Directory where recursive search starts.
   --  @param Query Case-insensitive name fragment to match.
   --  @param Classes Filetype and icon maps.
   --  @param Options Hidden-entry and sort policy.
   --  @param Max_Items Maximum number of matching items to return.
   --  @return Deterministic recursive search result or recoverable error.
   function Search_Names
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options;
      Max_Items : Natural := Max_Search_Results)
      return Recursive_Search_Result;

   --  Search a directory tree for text files whose first bytes contain Query.
   --
   --  @param Root_Path Directory where the search starts.
   --  @param Query Text to look for.
   --  @param Classes Filetype and icon maps.
   --  @param Options Hidden-entry and sort policy.
   --  @return The matching files, or why the search failed.
   function Search_Contents
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options)
      return Recursive_Search_Result;

end Files.File_System.Search.Testing;
