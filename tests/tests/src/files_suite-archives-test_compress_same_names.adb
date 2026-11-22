with Files_Suite.Listings;
with Files.UI_Types;
with Files.Operation_Results;
separate (Files_Suite.Archives)
   procedure Test_Compress_Same_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Result   : Files.Operation_Results.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "a"));
      Ada.Directories.Create_Path (Join (Root, "b"));
      Write_File (Join (Join (Root, "a"), "readme.txt"), "from a");
      Write_File (Join (Join (Root, "b"), "readme.txt"), "from b");

      --  A search finds both: one archive of the two keeps both, the second
      --  under a numbered name, rather than failing on the shared name.
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Filter (Model, "readme");
      Result := Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names);
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operation_Results.Operation_Success, "the search runs");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 2, "the search finds both files");
      Files.Model.Selection.Select_All_Visible (Model);
      Result := Operation_Commands.Compress_Selected (Model, Settings, Files.Operations.Zip_Archive);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operation_Results.Operation_Success, "two same-named files compress together");

      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Assert (Files.Model.Selection.Select_By_Name (Model, "readme.zip"), "the archive is made in the search root");
      Result := Operation_Commands.Extract_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operation_Results.Operation_Success, "the archive extracts");
      Assert (Path_Exists (Join (Join (Root, "readme"), "readme.txt"))
              and then Path_Exists (Join (Join (Root, "readme"), "readme 2.txt")),
              "both files are in it, the second as readme 2.txt");
      Project_Tools.Files.Delete_Tree (Join (Root, "a"));
      Project_Tools.Files.Delete_Tree (Join (Root, "b"));
      Project_Tools.Files.Delete_Tree (Join (Root, "readme"));
   end Test_Compress_Same_Names;
