with Files.File_System.Search;
with Files.File_System;
with Files.Settings;

--  The listings and searches as the suite calls them, by a whole settings
--  record: Files.File_System takes only the classification maps and the
--  listing options (Files.Settings.Classification_Of,
--  Files.Settings.Listing_Options_Of), which these derive from Settings as
--  the application's callers do.
package Files_Suite.Listings is

   --  Files.File_System.Load_Directory by Settings.
   --
   --  @param Path Directory path to load.
   --  @param Settings Settings to classify and list by.
   --  @return Load result.
   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Files.File_System.Directory_Load_Result;

   --  Files.File_System.Load_Directory_Generating_Thumbnails by Settings.
   --
   --  @param Path Directory path to load.
   --  @param Settings Settings to classify and list by.
   --  @return Load result.
   function Load_Directory_Generating_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Files.File_System.Directory_Load_Result;

   --  Files.File_System.Load_Directory_Deferring_Thumbnails by Settings.
   --
   --  @param Path Directory path to load.
   --  @param Settings Settings to classify and list by.
   --  @return Load result.
   function Load_Directory_Deferring_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Files.File_System.Directory_Load_Result;

   --  Files.File_System.Load_Item by Settings.
   --
   --  @param Full_Path Path to describe.
   --  @param Settings Settings to classify by.
   --  @return Load result.
   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Files.File_System.Item_Load_Result;

   --  Files.File_System.Search.Search_Names by Settings.
   --
   --  @param Root_Path Directory where the search starts.
   --  @param Query Name fragment.
   --  @param Settings Settings to classify and list by.
   --  @param Max_Items Maximum number of matches.
   --  @return Search result.
   function Search_Names
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := Files.File_System.Max_Search_Results)
      return Files.File_System.Search.Recursive_Search_Result;

   --  Files.File_System.Search.Search_Contents by Settings.
   --
   --  @param Root_Path Directory where the search starts.
   --  @param Query Text looked for.
   --  @param Settings Settings to classify and list by.
   --  @return Search result.
   function Search_Contents
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model)
      return Files.File_System.Search.Recursive_Search_Result;

   --  Where a listing holds an item called Name.
   --
   --  @param Load Listing result.
   --  @param Name Item name.
   --  @return Its index in Load.Items, the first such; 0 when it holds none.
   function Listed_Index (Load : Files.File_System.Directory_Load_Result; Name : String) return Natural;

   --  Whether a listing holds an item called Name.
   --
   --  @param Load Listing result.
   --  @param Name Item name.
   --  @return True when Load.Items has one.
   function Listed (Load : Files.File_System.Directory_Load_Result; Name : String) return Boolean;

end Files_Suite.Listings;
