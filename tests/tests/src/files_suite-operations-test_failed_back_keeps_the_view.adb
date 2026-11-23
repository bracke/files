with Files.Operations.Navigation;
with Files.Model.Filtering;
with Files.Model.Jobs;
with Files.Operation_Results;
separate (Files_Suite.Operations)
   --  In a window (background transfers on, as the GUI runs), Back reads
   --  the folder before it moves. Back to a folder that is gone fails and
   --  the window shows the view it left as it was: search results stay
   --  results, with their query, their selection, an item being renamed --
   --  the one being renamed, not another of the same name -- and a refresh
   --  it owes. Back that works shows the folder's own listing at once, the
   --  results' notice gone with them.
   procedure Test_Failed_Back_Keeps_The_View (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Gone     : constant String := Join (Root, "gone-back");
      Origin   : constant String := Join (Root, "origin");
      First    : constant String := Join (Join (Origin, "a"), "report.txt");
      Second   : constant String := Join (Join (Origin, "b"), "report.txt");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operation_Results.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Gone);
      Write_File (Join (Gone, "kept.txt"), "kept");
      Ada.Directories.Create_Path (Join (Origin, "a"));
      Ada.Directories.Create_Path (Join (Origin, "b"));
      Write_File (First, "first");
      Write_File (Second, "second");
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
      Files.Model.Selection.Restore (Model, Files.Types.String_Vectors.To_Vector (To_Unbounded_String (Second), 1),
                                     Second);
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Selection.Selected_Item (Model).Full_Path), Second, "the second report is selected");
      Files.Model.Rename.Toggle (Model);
      Files.Model.Rename.Set_Text (Model, "renamed.txt");
      Files.Model.Note_Owed_Refresh (Model, Force => True, Select_Name => "");
      Files.Model.Jobs.Set_Background_Transfers (Model, True);

      Project_Tools.Files.Delete_Tree (Gone);
      Step := Files.Operations.Navigation.Navigate_Back (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Failed, "back to a folder that is gone fails");
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), Origin, "the window stays where it was");
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "showing the search results still");
      Files_Suite.Support.Assert_Equal (Files.Model.Filtering.Filter_Text (Model), "report", "with their query");
      Assert (Files.Model.Item_Count (Model) = 2 and then Files.Model.Visible_Count (Model) = 2,
              "both results listed");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Selection.Selected_Item (Model).Full_Path), Second,
         "the result renamed is still the one selected");
      Assert (Files.Model.Rename.Is_Active (Model), "its rename goes on");
      Files_Suite.Support.Assert_Equal (Files.Model.Rename.Text (Model), "renamed.txt", "with the name typed");
      Assert (Files.Model.Refresh_Is_Owed (Model), "the refresh the view owed is owed still");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.directory.load", "the failure is said");
      Assert (Files.Model.Can_Go_Back (Model), "the way back is still there to try again");

      --  The folder is back, and so is a search notice: Back shows the
      --  folder's listing, with neither the results nor their notice.
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Ada.Directories.Create_Path (Gone);
      Write_File (Join (Gone, "kept.txt"), "kept");
      Files.Model.Set_Error (Model, "search.no_matches");
      Step := Files.Operations.Navigation.Navigate_Back (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Navigated, "back to the folder works");
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), Gone, "the window is back");
      Assert (not Files.Model.Filtering.Search_Results_Are_Active (Model), "showing no results");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 1, "but the folder's own listing");
      Files_Suite.Support.Assert_Equal (Files.Model.Last_Error_Key (Model), "", "the notice went with the results");
      Assert (Files.Model.Can_Go_Forward (Model), "with the way forward");
      Reset_Root;
   end Test_Failed_Back_Keeps_The_View;
