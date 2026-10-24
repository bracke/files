separate (Files_Suite.Operations)
   procedure Test_Search_Limit_Errors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Child : Unbounded_String;
      Search : Files.File_System.Recursive_Search_Result;
   begin
      Reset_Root;
      Child := To_Unbounded_String (Root);
      for Level in 1 .. 66 loop
         Append (Child, "/d");
         Ada.Directories.Create_Directory (To_String (Child));
      end loop;
      Write_Binary_File (Join (To_String (Child), "needle.txt"), "needle");
      for Background in Boolean loop
         for Contents in Boolean loop
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Set_Filter (Model, "needle");
            Files.Model.Set_Background_Transfers (Model, Background);
            Step := (if Contents then Files.Operations.Run_Content_Search (Model, Settings)
                     else Files.Operations.Run_Recursive_Search (Model, Settings));
            Step := Complete_Operation (Model, Settings, Step);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then To_String (Step.Error_Key) = "error.search.failed"
                    and then Files.Model.Item_Count (Model) = 1
                    and then not Files.Model.Search_Results_Are_Active (Model),
                    "a skipped deep subtree is a failed search, preserving the prior listing");
         end loop;
      end loop;
      Reset_Root;
      Write_Binary_File (Join (Root, "needle-a.txt"), "needle");
      Search := Files.File_System.Search_Recursive (Root, "needle", Settings, Max_Items => 1);
      Assert (Search.Success and then Natural (Search.Items.Length) = 1,
              "an exact final match limit is complete when nothing remains to scan");
      Write_Binary_File (Join (Root, "needle-b.txt"), "needle");
      Search := Files.File_System.Search_Recursive (Root, "needle", Settings, Max_Items => 1);
      Assert (not Search.Success and then To_String (Search.Error_Key) = "error.search.failed",
              "an additional skipped entry makes the search incomplete");
      for Background in Boolean loop
         for Oversized in Boolean loop
            Reset_Root;
            declare
               Bytes : String (1 .. 64 * 1024 + (if Oversized then 1 else 0)) := [others => 'a'];
            begin
               Bytes (Bytes'Last - 5 .. Bytes'Last) := "needle";
               Write_Binary_File (Join (Root, "large.txt"), Bytes);
            end;
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Set_Filter (Model, "needle");
            Files.Model.Set_Background_Transfers (Model, Background);
            Step := Complete_Operation (Model, Settings, Files.Operations.Run_Content_Search (Model, Settings));
            Assert (Step.Status = (if Oversized then Files.Operations.Operation_Failed
                                   else Files.Operations.Operation_Success)
                    and then (if Oversized then To_String (Step.Error_Key) = "error.search.failed"
                              else Files.Model.Visible_Count (Model) = 1),
                    "content reads distinguish a complete byte boundary from omitted bytes in helpers too");
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); raise;
   end Test_Search_Limit_Errors;
