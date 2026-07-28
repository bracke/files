with Files.Model;
with Files.Settings;

--  The recursive name/content search operations of Files.Operations, extracted
--  into a group child. A private child; the parent renames these.
private package Files.Operations.Search is

   --  Run a bounded recursive name search for the model's filter text and
   --  replace the item list with the matches.
   --
   --  @param Model Window model whose filter text drives the search.
   --  @param Settings Settings model used to classify the walk.
   --  @return Success result, or a failed/disabled result.
   function Run_Recursive_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Whether a file's (bounded) preview bytes contain the query, skipping
   --  binary payloads. Case-insensitive substring match.
   --
   --  @param Bytes File preview bytes to search.
   --  @param Query Query text to look for.
   --  @return True when Bytes is textual and contains Query.
   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean;

   --  Run a bounded recursive content search for the model's filter text and
   --  replace the item list with the files whose contents match.
   --
   --  @param Model Window model whose filter text drives the search.
   --  @param Settings Settings model used to load each directory.
   --  @return Success result, or a failed/disabled result.
   function Run_Content_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations.Search;
