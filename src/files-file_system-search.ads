--  Recursive name and content search below a folder. Clients with this,
--  not the whole of Files.File_System.
package Files.File_System.Search is

   --  Search a directory tree recursively for item names matching Query.
   --  A folder below the root that cannot be read is skipped (Incomplete),
   --  and a limit reached ends the walk (Truncated); both keep what was found.
   --
   --  @param Root_Path Directory where recursive search starts.
   --  @param Query Case-insensitive name fragment to match.
   --  @param Classes Filetype and icon maps items are classified by
   --    (Files.Settings.Classification_Of the settings).
   --  @param Options Hidden-entry and sort policy (Files.Settings.Listing_Options_Of).
   --  @param Max_Items Maximum number of matching items to return.
   --  @return Deterministic recursive search result or recoverable error.
   function Search_Names
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options;
      Max_Items : Natural := Max_Search_Results)
      return Recursive_Search_Result;

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

   --  Search a directory tree for text files whose first 64 KiB contain
   --  Query, ignoring case, with Search_Names's walk: real folders only
   --  (a linked folder is an item, so cycles are impossible), Max_Search_Depth
   --  deep, and cancellable. Past its limits (Max_Search_Results matches,
   --  20,000 files read) the answer is Truncated; a file it could not read,
   --  or a text file larger than it reads with no match in what it read,
   --  makes it Incomplete.
   --
   --  @param Root_Path Directory where the search starts.
   --  @param Query Text to look for.
   --  @param Classes Filetype and icon maps items are classified by
   --    (Files.Settings.Classification_Of the settings).
   --  @param Options Hidden-entry and sort policy (Files.Settings.Listing_Options_Of).
   --  @return The matching files, or why the search failed.
   function Search_Contents
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options)
      return Recursive_Search_Result;
end Files.File_System.Search;
