with Files.Model.Jobs;
with Files.Model.Filtering;
with Files.Operations.Editing;
with Files_Suite.Listings;
with Files.UI_Types;
with Files.Operation_Results;
with Files.Refresh;
with Files.Jobs.Process;
with Files_Suite.Support.Timing;
separate (Files_Suite.Search)
   --  Search results in a window (background transfers on, as the GUI
   --  always runs) may list two items of one name. A rename, and a helper's
   --  duplicate, select the item they made by its full path, not the first
   --  item of its name. Undo and Redo through their helper show the helper's
   --  own search afterwards, with none run again. Typing in the filter
   --  leaves a folder's read standing, and over results it changes only the
   --  field. The scope chip turned with no query reads the folder once and
   --  keeps the scope it turned to.
   procedure Test_Search_Results_Select_By_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      First    : constant String := Join (Join (Root, "a"), "b");
      Second   : constant String := Join (Join (Root, "a"), "c");
      Model    : Files.Model.Window_Model;
      Result   : Files.Operation_Results.Operation_Result;

      function Background_Read return Boolean is
        (Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)));

      function Shown (Path : String) return Boolean is (Files.Model.Visible_Index_Of (Model, Path) /= 0);

      function Selected_Path return String is
        (To_String (Files.Model.Selection.Selected_Item (Model).Full_Path));

      --  The window's poll brings a background read in.
      procedure Await_Read is
      begin
         for Attempt in Files_Suite.Support.Timing.Polling loop
            exit when Files.Refresh.Advance (Model, Settings);
         end loop;
      end Await_Read;

      --  The folder, in a window that runs its work in the background.
      procedure Show_Folder is
         Load : constant Files.File_System.Directory_Load_Result :=
           Files_Suite.Listings.Load_Directory (Root, Settings);
      begin
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Jobs.Set_Background_Transfers (Model, True);
      end Show_Folder;

      --  The recursive name search for Query, shown in that window.
      procedure Search (Query : String) is
      begin
         Show_Folder;
         Files.Model.Jobs.Set_Background_Transfers (Model, False);
         Files.Model.Filtering.Set_Filter (Model, Query);
         Result := Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names);
         Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "the search for " & Query & " is shown");
         Files.Model.Jobs.Set_Background_Transfers (Model, True);
      end Search;

      --  Two items named Leaf are shown, the one in First listed before the
      --  one in Second: a selection by name would take the first.
      procedure Assert_Two_Named (Leaf : String) is
      begin
         Assert (Shown (Join (First, Leaf)) and then Shown (Join (Second, Leaf)),
                 "both items named " & Leaf & " are among the results");
         Assert (Files.Model.Visible_Index_Of (Model, Join (First, Leaf))
                 < Files.Model.Visible_Index_Of (Model, Join (Second, Leaf)),
                 "the other " & Leaf & " is listed first");
      end Assert_Two_Named;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (First);
      Ada.Directories.Create_Path (Second);
      Write_File (Join (First, "foo.txt"), "one");
      Write_File (Join (First, "foo (copy).txt"), "two");
      Write_File (Join (Second, "fox.txt"), "three");

      --  A rename among the results, read again in the background.
      Search ("fo");
      Files.Model.Selection.Select_Visible (Model, Files.Model.Visible_Index_Of (Model, Join (Second, "fox.txt")));
      Files.Model.Rename.Toggle (Model);
      Files.Model.Rename.Set_Text (Model, "foo.txt");
      Result := Files.Operations.Editing.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operation_Results.Operation_Success, "the result renames");
      Assert (Background_Read, "the results are searched again in the background");
      Await_Read;
      Assert_Two_Named ("foo.txt");
      Files_Suite.Support.Assert_Equal
        (Selected_Path, Join (Second, "foo.txt"), "the renamed result is selected by its path");

      --  Undo and Redo of it through their helper: the helper's own search
      --  afterwards is the view.
      Result := Complete_Operation (Model, Settings, Operation_Commands.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operation_Results.Operation_Success, "the helper undoes the rename");
      Assert (Path_Exists (Join (Second, "fox.txt")), "the result has its old name");
      Assert (not Background_Read, "the helper's own search afterwards is shown, with none run again");
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model)
              and then Files.Model.Filtering.Search_Query (Model) = "fo"
              and then Shown (Join (Second, "fox.txt"))
              and then not Shown (Join (Second, "foo.txt")),
              "the results stay shown, with the undone name");
      Result := Complete_Operation (Model, Settings, Operation_Commands.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operation_Results.Operation_Success, "the helper redoes the rename");
      Assert (Path_Exists (Join (Second, "foo.txt")), "the result has its new name again");
      Assert (not Background_Read, "the helper's own search after the redo is shown, with none run again");
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model) and then Shown (Join (Second, "foo.txt")),
              "the results stay shown, with the redone name");

      --  A helper's duplicate selects the copy it made by its path.
      Files.Model.Selection.Select_Visible (Model, Files.Model.Visible_Index_Of (Model, Join (Second, "foo.txt")));
      Result := Complete_Operation (Model, Settings, Operation_Commands.Duplicate_Selected (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operation_Results.Operation_Success, "the helper duplicates the result");
      Assert (Path_Exists (Join (Second, "foo (copy).txt")), "the copy is made beside its source");
      Assert_Two_Named ("foo (copy).txt");
      Files_Suite.Support.Assert_Equal
        (Selected_Path, Join (Second, "foo (copy).txt"), "the helper's copy is selected by its path");

      --  Typing over the results changes the field alone.
      declare
         Rows   : constant Natural := Files.Model.Rows_Revision (Model);
         Scroll : constant Natural := Files.Model.Main_View_Scroll_Lines (Model);
      begin
         Files.Model.Filtering.Set_Filter (Model, "fx");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Filtering.Filter_Text (Model), "fx", "the field holds what is typed");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Rows_Revision (Model), Rows, "the results' rows are not built again");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Main_View_Scroll_Lines (Model), Scroll, "nor scrolled back");
         Files_Suite.Support.Assert_Equal
           (Selected_Path, Join (Second, "foo (copy).txt"), "and the selection stands");
      end;

      --  The chip turned with no query: the results end and the folder is
      --  read once, its scope kept.
      Files.Model.Filtering.Set_Filter (Model, "");
      declare
         Turned : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Search_Scope_Toggle (Model, Settings);
         pragma Unreferenced (Turned);
      begin
         null;
      end;
      Assert (not Files.Model.Filtering.Search_Results_Are_Active (Model), "the results end");
      Assert (Background_Read, "the folder is read in the background");
      Await_Read;
      Assert (not Files.Model.Refresh_Is_Owed (Model) and then not Background_Read,
              "that read lands: none is thrown away and read again");
      Assert (Shown (Join (Root, "a")) and then not Shown (Join (First, "foo.txt")),
              "the folder's own listing is shown");
      Assert (Files.Model.Filtering.Search_Scope_Of (Model) = Files.UI_Types.Search_Contents,
              "and the chip keeps the scope it turned to");

      --  Typing over a folder leaves its read standing.
      Show_Folder;
      Result := Files.Refresh.Start (Model, Settings, Force => True);
      Assert (Background_Read, "a read of the folder runs");
      declare
         Listing : constant Natural := Files.Model.Listing_Revision (Model);
      begin
         Files.Model.Filtering.Set_Filter (Model, "a");
         Files.Model.Filtering.Set_Filter (Model, "ab");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Listing_Revision (Model), Listing, "typing does not make the read stale");
      end;
      Await_Read;
      Assert (not Files.Model.Refresh_Is_Owed (Model) and then not Background_Read,
              "the read lands, with none owed or started again");
      Project_Tools.Files.Delete_Tree (Join (Root, "a"));
   end Test_Search_Results_Select_By_Path;
