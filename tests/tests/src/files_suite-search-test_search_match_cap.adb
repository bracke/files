with Files.Model.Jobs;
with Files.Model.Filtering;
with Files_Suite.Listings;
with Files.UI_Types;
with Files.Operation_Results;
with Files_Suite.Support.Guards;
with Files.Text_Basics;
with Files.Operations.Editing;
with Files.Refresh;
with Files.Jobs.Process;
with Files_Suite.Support.Timing;

separate (Files_Suite.Search)
   --  Reaching the match cap shows the first matches with the truncated
   --  notice instead of failing the search, in a helper too. Exactly as many
   --  matches as the cap is a complete answer, even with a folder (an empty
   --  one) still to walk once the cap is reached. An operation among the
   --  results searches them again, still capped: the notice stays, in the
   --  window and through a helper; listing the folder again clears it.
   procedure Test_Search_Match_Cap (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
      Search   : Files.File_System.Search.Recursive_Search_Result;

      --  The window's poll brings a background read in, if one runs.
      procedure Await_Read is
      begin
         for Attempt in Files_Suite.Support.Timing.Polling loop
            exit when not Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model))
              or else Files.Refresh.Advance (Model, Settings);
         end loop;
      end Await_Read;
   begin
      Reset_Root;
      for Index in 1 .. Files.File_System.Max_Search_Results loop
         Write_Binary_File (Join (Root, "needle-" & Files.Text_Basics.Natural_Text (Index) & ".txt"), "needle");
      end loop;
      Ada.Directories.Create_Directory (Join (Root, "empty-folder"));
      Search := Files_Suite.Listings.Search_Names (Root, "needle", Settings);
      Assert (Search.Success and then not Search.Truncated and then not Search.Incomplete,
              "exactly the cap's matches, and an empty folder left to walk, is a complete answer");
      Files_Suite.Support.Assert_Equal
        (Natural (Search.Items.Length), Files.File_System.Max_Search_Results, "every match is kept");
      Write_Binary_File
        (Join (Root, "needle-" & Files.Text_Basics.Natural_Text (Files.File_System.Max_Search_Results + 1) & ".txt"),
         "needle");
      Search := Files_Suite.Listings.Search_Names (Root, "needle", Settings);
      Assert (Search.Success and then Search.Truncated and then not Search.Incomplete,
              "one match past the cap truncates the name search");
      Files_Suite.Support.Assert_Equal
        (Natural (Search.Items.Length), Files.File_System.Max_Search_Results, "the first matches are kept");
      for Background in Boolean loop
         for Contents in Boolean loop
            Load := Files_Suite.Listings.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Filtering.Set_Filter (Model, "needle");
            Files.Model.Jobs.Set_Background_Transfers (Model, Background);
            Step := (if Contents then Operation_Commands.Run_Search (Model, Settings,
              Files.UI_Types.Search_Contents)
                     else Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names));
            Step := Complete_Operation (Model, Settings, Step);
            Assert (Step.Status = Files.Operation_Results.Operation_Success
                    and then Files.Model.Filtering.Search_Results_Are_Active (Model),
                    "a capped search succeeds, background " & Background'Image & ", contents " & Contents'Image);
            Files_Suite.Support.Assert_Equal
              (Files.Model.Item_Count (Model), Files.File_System.Max_Search_Results,
               "and shows the capped matches, background " & Background'Image & ", contents " & Contents'Image);
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Model), "search.truncated",
               "with the truncated notice, background " & Background'Image & ", contents " & Contents'Image);
         end loop;
      end loop;
      for Background in Boolean loop
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Filtering.Set_Filter (Model, "needle");
         Files.Model.Jobs.Set_Background_Transfers (Model, Background);
         Step := Complete_Operation
           (Model, Settings, Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names));
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "search.truncated",
            "the capped results say so, background " & Background'Image);

         --  A rename among them: read again here, or in the background.
         Files.Model.Selection.Select_Visible (Model, 1);
         Files.Model.Rename.Toggle (Model);
         Files.Model.Rename.Set_Text
           (Model, "needle-renamed-" & Boolean'Image (Background) & ".txt");
         Step := Files.Operations.Editing.Commit_Rename (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operation_Results.Operation_Success, "a result renames, background " & Background'Image);
         Await_Read;
         Assert (Files.Model.Filtering.Search_Results_Are_Active (Model),
                 "the renamed results are still results, background " & Background'Image);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "search.truncated",
            "searched again after a rename, they still say they are cut short, background " & Background'Image);

         --  A duplicate among them, through its helper in a window.
         Files.Model.Selection.Select_Visible (Model, 1);
         Step := Complete_Operation (Model, Settings, Operation_Commands.Duplicate_Selected (Model, Settings));
         Await_Read;
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "search.truncated",
            "searched again after a duplicate, they still say they are cut short, background " & Background'Image);

         --  The folder listed again: no results, no notice.
         Files.Model.Filtering.Clear_Filter (Model);
         Step := Files.Operations.Refresh (Model, Settings);
         Await_Read;
         Assert (not Files.Model.Filtering.Search_Results_Are_Active (Model),
                 "the folder is listed again, background " & Background'Image);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "",
            "and the search's notice is gone, background " & Background'Image);
      end loop;
   end Test_Search_Match_Cap;
