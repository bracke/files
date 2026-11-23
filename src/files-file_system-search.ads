with Files.UI_Types;

--  Recursive name and content search below a folder. Clients with this,
--  not the whole of Files.File_System.
package Files.File_System.Search is

   --  A search's answer. Success with Items is an answer to show, partial
   --  or not; only a root that could not be searched at all fails.
   type Recursive_Search_Result is record
      Success   : Boolean := False;
      Items     : Item_Vectors.Vector;
      Error_Key : UString;
      --  A limit stopped the walk before it saw everything (the match cap,
      --  Max_Search_Depth, the scan caps): Items are the first found.
      Truncated : Boolean := False;
      --  Something under the root could not be searched (a folder or file
      --  that could not be read, a text file longer than is read with no
      --  match in what was): a match there is missing from Items.
      Incomplete : Boolean := False;
   end record;

   --  Whether Key is one of the notices a search's answer is shown with
   --  ("search.truncated", "search.incomplete", "search.no_matches"): a notice about the results shown,
   --  not an operation's diagnostic, so it does not outlive them.
   --
   --  @param Key An error line's key.
   --  @return True for a search notice.
   function Is_Notice (Key : String) return Boolean is
     (Key in "search.truncated" | "search.incomplete" | "search.no_matches");

   --  A folder searched to show its results: the answer, the notice it is
   --  shown with and the folder's signature as the search left it.
   type Folder_Search_Result is record
      Success   : Boolean := False;
      Items     : Item_Vectors.Vector;
      Error_Key : UString;
      Notice    : UString;
      Signature : Directory_Signature;
   end record;

   --  The one search a view's results come from, in the window or in a
   --  helper: Search_Names or Search_Contents by Scope, its Notice_Of, and
   --  Directory_State of Root_Path when it answered.
   --
   --  @param Root_Path Directory where the search starts.
   --  @param Query What to search for.
   --  @param Scope By name or by content.
   --  @param Classes Filetype and icon maps items are classified by.
   --  @param Options Hidden-entry and sort policy.
   --  @return The results with their notice and signature, or why the
   --    search failed.
   function Search_Folder
     (Root_Path : String;
      Query     : String;
      Scope     : Files.UI_Types.Tree_Search_Scope;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options)
      return Folder_Search_Result;
private

   --  The notice a search's answer is shown with: "search.truncated" when a
   --  limit cut it short, "search.incomplete" when something went
   --  unsearched, "search.no_matches" when it found nothing, else "".
   --
   --  @param Found A successful search's answer.
   --  @return The notice key, or "".
   function Notice_Of (Found : Recursive_Search_Result) return String is
     (if Found.Truncated then "search.truncated"
      elsif Found.Incomplete then "search.incomplete"
      elsif Found.Items.Is_Empty then "search.no_matches"
      else "");

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

end Files.File_System.Search;
