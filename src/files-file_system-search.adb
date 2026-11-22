package body Files.File_System.Search is

   function Search_Names
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options;
      Max_Items : Natural := Max_Search_Results)
      return Recursive_Search_Result
     renames Files.File_System.Search_Names;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean
     renames Files.File_System.Content_Matches;

   function Search_Contents
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options)
      return Recursive_Search_Result
     renames Files.File_System.Search_Contents;

end Files.File_System.Search;
