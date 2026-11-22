with Files.Model.Jobs;
with Files.Operations.Editing;
with Files.Model.Filtering;
with Files_Suite.Listings;
with Files.UI_Types;
with Files.Operation_Results;
separate (Files_Suite.Search)
   procedure Test_Search_Result_Actions_Stay_Beside_Source (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Deep     : constant String := Join (Join (Root, "a"), "b");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Result   : Files.Operation_Results.Operation_Result;

      function Entries (Directory : String) return Natural is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
         Count  : Natural := 0;
      begin
         Ada.Directories.Start_Search (Search, Directory, "*");
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            if Ada.Directories.Simple_Name (Item) not in "." | ".." then
               Count := Count + 1;
            end if;
         end loop;
         Ada.Directories.End_Search (Search);
         return Count;
      end Entries;

      --  Show the recursive name search for Query, with its one hit selected.
      procedure Search (Query : String) is
      begin
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Jobs.Set_Background_Transfers (Model, False);
         Files.Model.Filtering.Set_Filter (Model, Query);
         Result := Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names);
         Assert (Files.Model.Filtering.Search_Results_Are_Active (Model) and then Files.Model.Item_Count (Model) = 1,
                 "the search finds the one deep file for " & Query);
         Files.Model.Selection.Select_Visible (Model, 1);
      end Search;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Deep);
      Write_File (Join (Deep, "report.txt"), "deep");

      Search ("report");
      Files.Model.Rename.Toggle (Model);
      Files.Model.Rename.Set_Text (Model, "summary.txt");
      Result := Files.Operations.Editing.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operation_Results.Operation_Success,
                                        "the search result renames");
      Assert (Path_Exists (Join (Deep, "summary.txt")) and then not Path_Exists (Join (Root, "summary.txt")),
              "the renamed result stays in its own folder, not the search root");

      Search ("summary");
      Result := Operation_Commands.Duplicate_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operation_Results.Operation_Success,
         "the search result duplicates");
      Assert (Entries (Deep) = 2 and then Entries (Root) = 1,
              "the duplicate is made beside its source, not in the search root");

      Search ("summary.txt");
      Result := Files.Operations.Editing.Create_Symlink_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operation_Results.Operation_Success,
         "a link to the search result is made");
      Assert (Hostkit.Fs.Is_Link (Join (Deep, "summary (link).txt"))
              and then not Path_Exists (Join (Root, "summary (link).txt")),
              "the link is made beside its source");

      --  The window runs these through a helper process, which rebuilds the
      --  model from its request: the results still count as results there.
      Search ("summary.txt");
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Result := Operation_Commands.Duplicate_Selected (Model, Settings);
      Result := Complete_Operation (Model, Settings, Result);
      Assert (Entries (Deep) = 4 and then Entries (Root) = 1,
              "a helper's duplicate of a search result is made beside its source");

      Load := Files_Suite.Listings.Load_Directory (Deep, Settings);
      Files.Model.Initialize (Model, Deep, Load.Items, Root);
      Files.Model.Jobs.Set_Background_Transfers (Model, False);
      Assert (Files.Model.Selection.Select_By_Name (Model, "summary.txt"), "the file to archive is listed");
      Result := Operation_Commands.Compress_Selected (Model, Settings, Files.Operations.Archives.Zip_Archive);
      Assert (Path_Exists (Join (Deep, "summary.zip")), "an archive is made beside the file");
      Search ("summary.zip");
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Result := Operation_Commands.Extract_Selected (Model, Settings);
      Result := Complete_Operation (Model, Settings, Result);
      Assert (Path_Exists (Join (Join (Deep, "summary"), "summary.txt"))
              and then not Path_Exists (Join (Root, "summary")),
              "a helper extracts a search result beside the archive, not into the search root");
      Project_Tools.Files.Delete_Tree (Join (Deep, "summary"));

      --  Clearing the filter ends the search: the folder's own listing comes
      --  back. Until it does, an action on a listed result still keeps to the
      --  result's own folder.
      Search ("summary.txt");
      declare
         Cleared : constant Files.Controller.Controller_Result :=
           Files.Controller.Execute_Non_Settings_Command (Files.Commands.Clear_Filter_Command, Model, Settings);
         pragma Unreferenced (Cleared);
      begin
         Assert (not Files.Model.Filtering.Search_Results_Are_Active (Model)
                 and then Files.Model.Item_Count (Model) = Entries (Root)
                 and then Files.Model.Selection.Select_By_Name (Model, "a"),
                 "Clear Filter lists the search root again, not the results");
      end;
      Search ("summary (copy).txt");
      Files.Model.Filtering.Clear_Filter (Model);
      Files.Model.Rename.Toggle (Model);
      Files.Model.Rename.Set_Text (Model, "notes.txt");
      Result := Files.Operations.Editing.Commit_Rename (Model, Settings);
      Assert (Path_Exists (Join (Deep, "notes.txt")) and then not Path_Exists (Join (Root, "notes.txt")),
              "a result still listed after Clear Filter renames in its own folder");
      Project_Tools.Files.Delete_Tree (Join (Root, "a"));
   end Test_Search_Result_Actions_Stay_Beside_Source;
