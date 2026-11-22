package body Files.File_System.Search.Testing is

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean renames Files.File_System.Search.Content_Matches;

end Files.File_System.Search.Testing;
