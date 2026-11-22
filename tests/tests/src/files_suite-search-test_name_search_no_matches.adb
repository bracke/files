with Files.Model.Filtering;
with Files_Suite.Listings;
with Files.UI_Types;
with Files.Operation_Results;
with Files_Suite.Support.Guards;
separate (Files_Suite.Search)
   --  A name search that finds nothing shows an empty answer with the same
   --  no-matches notice a content search gives, in a helper too.
   procedure Test_Name_Search_No_Matches (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Join (Root, "nested"));
      Write_Binary_File (Join (Root, "present.txt"), "bytes");
      Write_Binary_File (Join (Join (Root, "nested"), "also-present.txt"), "bytes");
      for Background in Boolean loop
         Load := Files_Suite.Listings.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Filtering.Set_Filter (Model, "absent");
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Complete_Operation
           (Model, Settings, Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names));
         Assert (Step.Status = Files.Operation_Results.Operation_Success
                 and then Files.Model.Filtering.Search_Results_Are_Active (Model)
                 and then Files.Model.Item_Count (Model) = 0,
                 "a name search with no match shows an empty answer, background " & Background'Image);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "search.no_matches",
            "with the no-matches notice, background " & Background'Image);
      end loop;
   end Test_Name_Search_No_Matches;
