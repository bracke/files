package body Files.File_System.Search.Testing is

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean renames Files.File_System.Search.Content_Matches;

   function Notice_Of (Found : Recursive_Search_Result) return String
     renames Files.File_System.Search.Notice_Of;

   function Search_Names
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options;
      Max_Items : Natural := Max_Search_Results)
      return Recursive_Search_Result renames Files.File_System.Search.Search_Names;

   function Search_Contents
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options)
      return Recursive_Search_Result renames Files.File_System.Search.Search_Contents;

end Files.File_System.Search.Testing;
