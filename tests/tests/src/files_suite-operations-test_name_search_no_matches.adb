separate (Files_Suite.Operations)
   --  A name search that finds nothing shows an empty answer with the same
   --  no-matches notice a content search gives, in a helper too.
   procedure Test_Name_Search_No_Matches (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Join (Root, "nested"));
      Write_Binary_File (Join (Root, "present.txt"), "bytes");
      Write_Binary_File (Join (Join (Root, "nested"), "also-present.txt"), "bytes");
      for Background in Boolean loop
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Filter (Model, "absent");
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Complete_Operation (Model, Settings, Files.Operations.Run_Recursive_Search (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Files.Model.Search_Results_Are_Active (Model)
                 and then Files.Model.Item_Count (Model) = 0,
                 "a name search with no match shows an empty answer, background " & Background'Image);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "search.no_matches",
            "with the no-matches notice, background " & Background'Image);
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); raise;
   end Test_Name_Search_No_Matches;
