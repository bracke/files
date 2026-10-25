separate (Files_Suite.Operations)
   procedure Test_Search_Result_Actions_Stay_Beside_Source (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Deep     : constant String := Join (Join (Root, "a"), "b");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Result   : Files.Operations.Operation_Result;

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
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Filter (Model, Query);
         Result := Files.Operations.Run_Recursive_Search (Model, Settings);
         Assert (Files.Model.Search_Results_Are_Active (Model) and then Files.Model.Item_Count (Model) = 1,
                 "the search finds the one deep file for " & Query);
         Files.Model.Select_Visible (Model, 1);
      end Search;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Deep);
      Write_File (Join (Deep, "report.txt"), "deep");

      Search ("report");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "summary.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "the search result renames");
      Assert (Path_Exists (Join (Deep, "summary.txt")) and then not Path_Exists (Join (Root, "summary.txt")),
              "the renamed result stays in its own folder, not the search root");

      Search ("summary");
      Result := Files.Operations.Duplicate_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "the search result duplicates");
      Assert (Entries (Deep) = 2 and then Entries (Root) = 1,
              "the duplicate is made beside its source, not in the search root");

      Search ("summary.txt");
      Result := Files.Operations.Create_Symlink_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "a link to the search result is made");
      Assert (Hostkit.Fs.Is_Link (Join (Deep, "summary (link).txt"))
              and then not Path_Exists (Join (Root, "summary (link).txt")),
              "the link is made beside its source");
      Project_Tools.Files.Delete_Tree (Join (Root, "a"));
   end Test_Search_Result_Actions_Stay_Beside_Source;
