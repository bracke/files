with Files.File_Types;
with Files.Types;

package body Files_Suite.Listings is

   function Classes (Settings : Files.Settings.Settings_Model) return Files.File_Types.Classification
     renames Files.Settings.Classification_Of;

   function Options (Settings : Files.Settings.Settings_Model) return Files.Types.Listing_Options
     renames Files.Settings.Listing_Options_Of;

   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Files.File_System.Directory_Load_Result is
     (Files.File_System.Load_Directory (Path, Classes (Settings), Options (Settings)));

   function Load_Directory_Generating_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Files.File_System.Directory_Load_Result is
     (Files.File_System.Load_Directory_Generating_Thumbnails (Path, Classes (Settings), Options (Settings)));

   function Load_Directory_Deferring_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Files.File_System.Directory_Load_Result is
     (Files.File_System.Load_Directory_Deferring_Thumbnails (Path, Classes (Settings), Options (Settings)));

   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Files.File_System.Item_Load_Result is
     (Files.File_System.Load_Item (Full_Path, Classes (Settings)));

   function Search_Names
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := Files.File_System.Max_Search_Results)
      return Files.File_System.Search.Recursive_Search_Result is
     (Files.File_System.Search.Search_Names (Root_Path, Query, Classes (Settings), Options (Settings), Max_Items));

   function Search_Contents
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model)
      return Files.File_System.Search.Recursive_Search_Result is
     (Files.File_System.Search.Search_Contents (Root_Path, Query, Classes (Settings), Options (Settings)));

end Files_Suite.Listings;
