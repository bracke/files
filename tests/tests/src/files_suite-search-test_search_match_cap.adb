separate (Files_Suite.Search)
   --  Reaching the match cap shows the first matches with the truncated
   --  notice instead of failing the search, in a helper too. Exactly as many
   --  matches as the cap is a complete answer, even with a folder (an empty
   --  one) still to walk once the cap is reached.
   procedure Test_Search_Match_Cap (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      Search   : Files.File_System.Recursive_Search_Result;
   begin
      Reset_Root;
      for Index in 1 .. Files.File_System.Max_Search_Results loop
         Write_Binary_File (Join (Root, "needle-" & Files.Types.Natural_Text (Index) & ".txt"), "needle");
      end loop;
      Ada.Directories.Create_Directory (Join (Root, "empty-folder"));
      Search := Files.File_System.Search_Names (Root, "needle", Settings);
      Assert (Search.Success and then not Search.Truncated and then not Search.Incomplete,
              "exactly the cap's matches, and an empty folder left to walk, is a complete answer");
      Files_Suite.Support.Assert_Equal
        (Natural (Search.Items.Length), Files.File_System.Max_Search_Results, "every match is kept");
      Write_Binary_File
        (Join (Root, "needle-" & Files.Types.Natural_Text (Files.File_System.Max_Search_Results + 1) & ".txt"),
         "needle");
      Search := Files.File_System.Search_Names (Root, "needle", Settings);
      Assert (Search.Success and then Search.Truncated and then not Search.Incomplete,
              "one match past the cap truncates the name search");
      Files_Suite.Support.Assert_Equal
        (Natural (Search.Items.Length), Files.File_System.Max_Search_Results, "the first matches are kept");
      for Background in Boolean loop
         for Contents in Boolean loop
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Set_Filter (Model, "needle");
            Files.Model.Set_Background_Transfers (Model, Background);
            Step := (if Contents then Files.Operations.Run_Search (Model, Settings, Files.Types.Search_Contents)
                     else Files.Operations.Run_Search (Model, Settings, Files.Types.Search_Names));
            Step := Complete_Operation (Model, Settings, Step);
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then Files.Model.Search_Results_Are_Active (Model),
                    "a capped search succeeds, background " & Background'Image & ", contents " & Contents'Image);
            Files_Suite.Support.Assert_Equal
              (Files.Model.Item_Count (Model), Files.File_System.Max_Search_Results,
               "and shows the capped matches, background " & Background'Image & ", contents " & Contents'Image);
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Model), "search.truncated",
               "with the truncated notice, background " & Background'Image & ", contents " & Contents'Image);
         end loop;
      end loop;
   end Test_Search_Match_Cap;
