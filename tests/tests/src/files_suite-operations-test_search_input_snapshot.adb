separate (Files_Suite.Operations)
   procedure Test_Search_Input_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Outcome : Files.Controller.Controller_Result;
      Revision : Natural;
   begin
      for Contents in Boolean loop
         for Stale in Boolean loop
            Reset_Root;
            Write_Binary_File (Join (Root, "alpha.txt"), "alpha bytes");
            Write_Binary_File (Join (Root, "beta.txt"), "beta bytes");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Set_Background_Transfers (Model, True);
            Files.Model.Set_Filter (Model, "alpha");
            Files.Model.Focus_Filter_Input (Model);
            Step := (if Contents then Files.Operations.Run_Content_Search (Model, Settings)
                     else Files.Operations.Run_Recursive_Search (Model, Settings));
            Revision := Files.Model.Revision (Model);
            Outcome := Files.Controller.Append_Focused_Text (Model, "x");
            Assert (Outcome.Status = Files.Controller.Controller_Ignored
                    and then Files.Model.Filter_Text (Model) = "alpha"
                    and then Files.Model.Revision (Model) = Revision,
                    "native character input cannot edit the active search snapshot");
            if Stale then
               Files.Model.Set_Filter (Model, "beta");
            end if;
            Step := Complete_Operation (Model, Settings, Step);
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then Files.Model.Search_Results_Are_Active (Model) = not Stale
                    and then Files.Model.Item_Count (Model) = (if Stale then 2 else 1),
                    "changed queries discard old outcomes while unchanged searches apply");
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); raise;
   end Test_Search_Input_Snapshot;
