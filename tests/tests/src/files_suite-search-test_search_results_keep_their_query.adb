with Files.Model.Jobs;
with Files.Model.Filtering;
with Files_Suite.Listings;
with Files.UI_Types;
with Files.Operation_Results;
with Files.Refresh;
with Files.Jobs.Process;
with Files_Suite.Support.Timing;
separate (Files_Suite.Search)
   --  Search results answer the query they were found for, whatever the
   --  filter field holds since: in a window (background transfers on, as
   --  the GUI always runs) a read searching them again asks for that query,
   --  typing meanwhile neither spoils that read nor starts another, and an
   --  operation's helper searches again for it too. New results settle a
   --  reload owed to the folder, so the search does not run twice; and a
   --  reload owed to an item named by its full path selects that item.
   procedure Test_Search_Results_Keep_Their_Query (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      First    : constant String := Join (Join (Root, "a"), "b");
      Second   : constant String := Join (Join (Root, "a"), "c");
      Model    : Files.Model.Window_Model;
      Result   : Files.Operation_Results.Operation_Result;

      function Background_Read return Boolean is
        (Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)));

      --  The window's poll brings a background read in.
      procedure Await_Read is
      begin
         for Attempt in Files_Suite.Support.Timing.Polling loop
            exit when Files.Refresh.Advance (Model, Settings);
         end loop;
      end Await_Read;

      --  The folder, then the recursive name search for Query, shown in a
      --  window that runs its work in the background.
      procedure Search (Query : String) is
         Load : constant Files.File_System.Directory_Load_Result :=
           Files_Suite.Listings.Load_Directory (Root, Settings);
      begin
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Jobs.Set_Background_Transfers (Model, False);
         Files.Model.Filtering.Set_Filter (Model, Query);
         Result := Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names);
         Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "the search for " & Query & " is shown");
         Files.Model.Jobs.Set_Background_Transfers (Model, True);
      end Search;

      function Shown (Path : String) return Boolean is (Files.Model.Visible_Index_Of (Model, Path) /= 0);
   begin
      Reset_Root;
      Ada.Directories.Create_Path (First);
      Ada.Directories.Create_Path (Second);
      Write_File (Join (First, "foo.txt"), "one");
      Write_File (Join (First, "fox.txt"), "two");
      Write_File (Join (Second, "foo.txt"), "three");

      --  A read searching the results again, with the field edited before
      --  and while it runs.
      Search ("foo");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filtering.Search_Query (Model), "foo", "the results keep the query they answer");
      Files.Model.Filtering.Set_Filter (Model, "fo");
      Result := Files.Refresh.Start (Model, Settings, Force => True, Search_Again => True);
      Assert (Background_Read, "the results are searched again in the background");
      Files.Model.Filtering.Set_Filter (Model, "f");
      Await_Read;
      Assert (not Files.Model.Refresh_Is_Owed (Model) and then not Background_Read,
              "typing in the field leaves the read standing, and starts no search of the text typed");
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model)
              and then Files.Model.Item_Count (Model) = 2
              and then Shown (Join (First, "foo.txt")) and then Shown (Join (Second, "foo.txt"))
              and then not Shown (Join (First, "fox.txt")),
              "the read answered the results' query, not the text typed since");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filtering.Search_Query (Model), "foo", "the results still answer it");

      --  An operation's helper searches again for the results' query.
      Assert (Files.Model.Selection.Select_By_Name (Model, "foo.txt"), "a result to delete is listed");
      Files.Model.Filtering.Set_Filter (Model, "fo");
      Result := Operation_Commands.Delete_Selected_Permanently (Model, Settings);
      Result := Complete_Operation (Model, Settings, Result);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operation_Results.Operation_Success, "the helper deletes the result");
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model)
              and then Files.Model.Item_Count (Model) = 1
              and then not Shown (Join (First, "fox.txt")),
              "the helper's search afterwards answered the results' query, not the field's");
      Write_File (Join (First, "foo.txt"), "one");

      --  A reload owed to the folder (its thumbnails, say) is settled by
      --  a new search's results instead of searching them again.
      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files_Suite.Listings.Load_Directory (Root, Settings);
      begin
         Files.Model.Initialize (Model, Root, Load.Items, Root);
      end;
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Result := Files.Refresh.Start (Model, Settings, Force => True);
      Assert (Background_Read, "a forced listing of the folder runs");
      Files.Model.Filtering.Set_Filter (Model, "foo");
      Result := Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names);
      Assert (Files.Model.Jobs.Foreground_Job_Is_Active (Model), "the search runs in its helper");
      Assert (not Files.Refresh.Advance (Model, Settings), "the listing waits for the search");
      Assert (Files.Model.Refresh_Is_Owed (Model) and then not Background_Read, "and is owed");
      Result := Complete_Operation (Model, Settings, Result);
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "the search's results are shown");
      Assert (not Files.Model.Refresh_Is_Owed (Model), "and settle the listing owed to the folder");
      Files.Refresh.Resume_Owed (Model, Settings);
      Assert (not Background_Read, "so the search does not run a second time");

      --  A reload asked to select an item by its full path, owed when the
      --  read went stale, selects that item -- not the first of its name.
      Search ("foo");
      Files.Model.Selection.Select_Visible (Model, Files.Model.Visible_Index_Of (Model, Join (First, "foo.txt")));
      Result := Files.Refresh.Start
        (Model, Settings, Force => True, Select_Path => Join (Second, "foo.txt"), Search_Again => True);
      Assert (Background_Read, "the results are searched again");
      Files.Model.Filtering.Set_Search_Scope (Model, Files.UI_Types.Search_Names);
      Assert (not Files.Refresh.Advance (Model, Settings) and then Files.Model.Refresh_Is_Owed (Model),
              "a read gone stale is owed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Owed_Refresh_Path (Model), Join (Second, "foo.txt"), "with the item it was to select");
      Files.Refresh.Resume_Owed (Model, Settings);
      Assert (Background_Read, "the owed read runs");
      Await_Read;
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Selection.Selected_Item (Model).Full_Path), Join (Second, "foo.txt"),
         "and selects the item by its path");
      Project_Tools.Files.Delete_Tree (Join (Root, "a"));
   end Test_Search_Results_Keep_Their_Query;
