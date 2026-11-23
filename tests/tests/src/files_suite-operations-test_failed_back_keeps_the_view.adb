with Files.Operations.Navigation;
with Files.Model.Filtering;
with Files.Operation_Results;
separate (Files_Suite.Operations)
   --  Back to a folder that is gone fails, and the window shows the view it
   --  left as it was: search results stay results, with their query, their
   --  selection and their scroll -- not the results' rows passed off as the
   --  folder's own listing with the query and selection gone.
   procedure Test_Failed_Back_Keeps_The_View (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Gone     : constant String := Join (Root, "gone-back");
      Origin   : constant String := Join (Root, "origin");
      Deep     : constant String := Join (Join (Origin, "sub"), "deep-report.txt");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operation_Results.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Gone);
      Ada.Directories.Create_Path (Join (Origin, "sub"));
      Write_File (Deep, "deep");
      Write_File (Join (Origin, "report.txt"), "top");
      Write_File (Join (Origin, "other.txt"), "other");
      Files.Model.Initialize (Model, Gone, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files_Suite.Support.Discard (Files.Operations.Refresh (Model, Settings));
      Files_Suite.Support.Discard
        (Files.Operations.Navigation.Navigate_And_Select (Model, Settings, Join (Origin, "other.txt")));
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), Origin, "the window moved on");
      Assert (Files.Model.Can_Go_Back (Model), "with the way back");

      Files.Model.Filtering.Set_Filter (Model, "report");
      Step := Files.Operations.Navigation.Run_Search (Model, Settings, Files.UI_Types.Search_Names);
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model) and then Files.Model.Item_Count (Model) = 2,
              "the search finds both reports");
      Assert (Files.Model.Selection.Select_By_Name (Model, "deep-report.txt"), "the deep one is listed");

      Project_Tools.Files.Delete_Tree (Gone);
      Step := Files.Operations.Navigation.Navigate_Back (Model, Settings);
      Assert (Step.Status /= Files.Operation_Results.Operation_Success, "back to a folder that is gone fails");
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), Origin, "the window stays where it was");
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "showing the search results still");
      Files_Suite.Support.Assert_Equal (Files.Model.Filtering.Filter_Text (Model), "report", "with their query");
      Assert (Files.Model.Item_Count (Model) = 2 and then Files.Model.Visible_Count (Model) = 2,
              "both results listed");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Selection.Selected_Item (Model).Full_Path), Deep, "and the result selected");
      Assert (Files.Model.Can_Go_Back (Model), "the way back is still there to try again");
      Reset_Root;
   end Test_Failed_Back_Keeps_The_View;
