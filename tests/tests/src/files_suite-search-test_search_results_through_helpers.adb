with Ada.Environment_Variables;
with Files.File_System.Trash;
with Files.Model.Jobs;
with Files.Model.Filtering;
with Files_Suite.Listings;
with Files.UI_Types;
with Files.Operation_Results;
with Files.Refresh;
with Files.Jobs.Process;
with Files_Suite.Support.Timing;
separate (Files_Suite.Search)
   --  Search results in a window (background transfers on, as the GUI
   --  always runs). A read searching them again that went stale while it
   --  ran -- the results' scope or the settings changed meanwhile -- is not
   --  shown: it is owed, and searches again for what the window shows now.
   --  A helper that trashes results, or restores results found in the
   --  trash, searches again after it acts: its results are shown as they
   --  are, without a second search, and without the items it moved.
   procedure Test_Search_Results_Through_Helpers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      First    : constant String := Join (Join (Root, "a"), "b");
      Second   : constant String := Join (Join (Root, "a"), "c");
      Model    : Files.Model.Window_Model;
      Result   : Files.Operation_Results.Operation_Result;

      function Background_Read return Boolean is
        (Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)));

      function Shown (Path : String) return Boolean is (Files.Model.Visible_Index_Of (Model, Path) /= 0);

      --  The window's poll brings a background read in, under With_Settings.
      procedure Await_Read (With_Settings : Files.Settings.Settings_Model) is
      begin
         for Attempt in Files_Suite.Support.Timing.Polling loop
            exit when Files.Refresh.Advance (Model, With_Settings);
         end loop;
      end Await_Read;

      --  The recursive name search for Query from Folder, shown in a window
      --  that runs its work in the background.
      procedure Search (Folder, Query : String) is
         Load : constant Files.File_System.Directory_Load_Result :=
           Files_Suite.Listings.Load_Directory (Folder, Settings);
      begin
         Files.Model.Initialize (Model, Folder, Load.Items, Root);
         Files.Operations.Settle_Current_Is_Trash (Model);
         Files.Model.Jobs.Set_Background_Transfers (Model, False);
         Files.Model.Filtering.Set_Filter (Model, Query);
         Result := Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names);
         Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "the search for " & Query & " is shown");
         Files.Model.Jobs.Set_Background_Transfers (Model, True);
      end Search;

      --  Start a read searching the results again, and let it finish.
      procedure Search_Again_Ready is
      begin
         Result := Files.Refresh.Start (Model, Settings, Force => True, Search_Again => True);
         Assert (Background_Read, "the results are searched again in the background");
         Await_Refresh_Ready (Model, "the read searching the results again finishes");
      end Search_Again_Ready;

      --  Trash two of three results, then restore one of them from results
      --  found in the trash, each through its helper.
      procedure Trash_And_Restore is
         Trash_Home : constant String := Root & "_xdg_data";
      begin
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
         Ada.Environment_Variables.Set ("HOME", Trash_Home);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Ada.Directories.Create_Path (First);
         Ada.Directories.Create_Path (Second);
         Write_File (Join (First, "foo.txt"), "one");
         Write_File (Join (Second, "foo.txt"), "two");
         Write_File (Join (First, "fox.txt"), "three");

         Search (Root, "fo");
         Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 3, "the search finds three results");
         Files.Model.Selection.Select_Visible (Model, Files.Model.Visible_Index_Of (Model, Join (First, "foo.txt")));
         Files.Model.Selection.Toggle_Visible_Selection
           (Model, Files.Model.Visible_Index_Of (Model, Join (Second, "foo.txt")));
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selection.Selected_Count (Model), 2, "two results are selected");
         Result := Complete_Operation (Model, Settings, Operation_Commands.Delete_Selected (Model, Settings));
         Files_Suite.Support.Assert_Equal
           (Result.Status, Files.Operation_Results.Operation_Success, "the helper trashes both");
         Assert (not Path_Exists (Join (First, "foo.txt")) and then not Path_Exists (Join (Second, "foo.txt")),
                 "both results are moved to the trash");
         Assert (not Background_Read, "the helper's own search afterwards is shown, with none run again");
         Assert (Files.Model.Filtering.Search_Results_Are_Active (Model)
                 and then Files.Model.Filtering.Search_Query (Model) = "fo",
                 "the results stay shown, with their query");
         Assert (Files.Model.Item_Count (Model) = 1 and then Shown (Join (First, "fox.txt")),
                 "without the trashed results, with the one left");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selection.Selected_Count (Model), 0, "and none of the trashed results selected");

         --  Results found in the trash: one restored through its helper.
         Search (Files.File_System.Trash.Trash_Files_Directory, "foo");
         Assert (Files.Model.Current_Is_Trash (Model), "the search runs in the trash");
         Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 2, "both trashed results are found");
         Files.Model.Selection.Select_Visible (Model, 1);
         Result := Complete_Operation
           (Model, Settings, Operation_Commands.Restore_Selected_From_Trash (Model, Settings));
         Files_Suite.Support.Assert_Equal
           (Result.Status, Files.Operation_Results.Operation_Success, "the helper restores the result");
         Assert (Path_Exists (Join (First, "foo.txt")) /= Path_Exists (Join (Second, "foo.txt")),
                 "one of the two is back in its folder");
         Assert (not Background_Read, "the helper's own search of the trash is shown, with none run again");
         Assert (Files.Model.Filtering.Search_Results_Are_Active (Model)
                 and then Files.Model.Filtering.Search_Query (Model) = "foo",
                 "the trash's results stay shown, with their query");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Item_Count (Model), 1, "without the restored result, with the other one");
         Project_Tools.Files.Delete_Tree (Join (Root, "a"));
      end Trash_And_Restore;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (First);
      Write_File (Join (First, "foo.txt"), "one");
      Write_File (Join (First, "notes.md"), "a foo inside");
      Write_File (Join (First, ".foo"), "hidden");

      --  The results' scope changed while the read searching them again ran.
      Search (Root, "foo");
      Assert (Shown (Join (First, "foo.txt")) and then not Shown (Join (First, "notes.md")),
              "the name search finds the file named foo");
      Search_Again_Ready;
      Files.Model.Filtering.Set_Search_Scope (Model, Files.UI_Types.Search_Contents);
      Assert (not Files.Refresh.Advance (Model, Settings), "the stale read is not shown");
      Assert (Files.Model.Refresh_Is_Owed (Model) and then not Background_Read, "it is owed");
      Assert (Shown (Join (First, "foo.txt")) and then not Shown (Join (First, "notes.md")),
              "the results stay as they were");
      Files.Refresh.Resume_Owed (Model, Settings);
      Assert (Background_Read, "the owed read runs");
      Await_Read (Settings);
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model)
              and then Files.Model.Filtering.Search_Scope_Of (Model) = Files.UI_Types.Search_Contents
              and then Files.Model.Filtering.Search_Query (Model) = "foo",
              "the owed read answers the results' query in their scope now");
      Assert (Shown (Join (First, "notes.md")) and then not Shown (Join (First, "foo.txt")),
              "it searched the contents, as the window shows them now");

      --  The settings changed while the read searching them again ran.
      Search (Root, "foo");
      Search_Again_Ready;
      declare
         Showing_Hidden : Files.Settings.Settings_Model := Settings;
      begin
         Showing_Hidden.Show_Hidden_Files := True;
         Assert (not Files.Refresh.Advance (Model, Showing_Hidden), "a read under other settings is not shown");
         Assert (Files.Model.Refresh_Is_Owed (Model) and then not Shown (Join (First, ".foo")),
                 "it is owed, the results as they were");
         Files.Refresh.Resume_Owed (Model, Showing_Hidden);
         Await_Read (Showing_Hidden);
         Assert (Files.Model.Filtering.Search_Results_Are_Active (Model) and then Shown (Join (First, ".foo")),
                 "the owed read searches again under the settings in force");
      end;

      Reset_Root;
      With_Trash_Environment (Trash_And_Restore'Access);
   end Test_Search_Results_Through_Helpers;
