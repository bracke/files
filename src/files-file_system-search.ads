--  The search operations of Files.File_System, extracted into
--  a concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.File_System.Search is

   --  Search a directory tree recursively for item names matching Query.
   --
   --  @param Root_Path Directory where recursive search starts.
   --  @param Query Case-insensitive name fragment to match.
   --  @param Settings Settings used for filetype, icon, and hidden-file policy.
   --  @param Max_Items Maximum number of matching items to return.
   --  @return Deterministic recursive search result or recoverable error.
   function Search_Recursive
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := 1_000)
      return Recursive_Search_Result;

end Files.File_System.Search;
