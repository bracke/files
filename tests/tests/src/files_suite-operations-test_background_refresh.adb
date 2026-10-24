separate (Files_Suite.Operations)
   procedure Test_Background_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Load : Files.File_System.Directory_Load_Result;
      Routed : Files.Interaction.Interaction_Result;
      Fault_Name : constant String := "FILES_TEST_REFRESH_RESULT_INCONSISTENT";
      Had_Fault : constant Boolean := Ada.Environment_Variables.Exists (Fault_Name);
      Old_Fault : constant String := Ada.Environment_Variables.Value (Fault_Name, "");

      procedure Restore_Fault is
      begin
         if Had_Fault then
            Ada.Environment_Variables.Set (Fault_Name, Old_Fault);
         else
            Ada.Environment_Variables.Clear (Fault_Name);
         end if;
      end Restore_Fault;

      procedure Await_Refresh (Expected : Boolean) is
         Applied : Boolean := False;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
            exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
         end loop;
         Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
                 "the background read finishes without synchronous enumeration");
         Assert (Applied = Expected, "only a matching changed snapshot replaces the visible listing");
      end Await_Refresh;

      procedure Await_Ready is
         Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled, "the stale snapshot is ready before the view changes");
      end Await_Ready;
   begin
      Ada.Environment_Variables.Clear (Fault_Name);
      Reset_Root;
      Write_Binary_File (Join (Root, "alpha"), "alpha");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Files.Model.Set_Directory_Signature (Model, Files.File_System.Directory_State (Root));
      Select_Name (Model, "alpha");
      Write_Binary_File (Join (Root, "beta"), "beta");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert (Step.Status = Files.Operations.Operation_Success
              and then Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model))
              and then Files.Model.Item_Count (Model) = 1,
              "watch polling schedules a read while retaining the displayed items");
      Await_Refresh (True);
      Assert (Files.Model.Item_Count (Model) = 2 and then Files.Model.Selected_Name (Model) = "alpha",
              "a changed snapshot adds the new item and preserves selection");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Ready;
      Select_Name (Model, "beta");
      Await_Refresh (True);
      Assert (Files.Model.Selected_Name (Model) = "beta",
              "selection changes neither stale a directory read nor get overwritten by its old selection");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Ready;
      Files.Model.Toggle_Visible_Selection (Model, 1);
      Await_Refresh (True);
      Assert
        (Files.Model.Selected_Count (Model) = 2
         and then Files.Model.Selected_Name (Model) = "alpha",
         "a completed directory read preserves a newer multi-selection and its primary item");
      Write_Binary_File (Join (Root, "inconsistent"), "inconsistent");
      Ada.Environment_Variables.Set (Fault_Name, "1");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Await_Ready;
      Ada.Environment_Variables.Clear (Fault_Name);
      Ada.Directories.Delete_File (Join (Root, "inconsistent"));
      Await_Refresh (False);
      Assert (Files.Model.Item_Count (Model) = 2
              and then Files.Model.Last_Error_Key (Model) = "error.directory.load",
              "an inconsistent helper outcome is rejected without replacing the listing");
      Files.Interaction.Apply_Right_Click
        (Model, Settings, In_Main => True, Item_Index => 0,
         X => 0, Y => 0, Result => Routed);
      Assert
        (Files.Model.Context_Menu_Is_Open (Model),
         "the refresh recovery path opens the empty-area context menu");
      Files.Interaction.Apply_Context_Menu_Command
        (Model, Settings, "", Files.Commands.Refresh_Directory_Command, 16, Guikit.Input.No_Modifiers, Routed);
      Await_Refresh (True);
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Await_Refresh (False);

      Write_Binary_File (Join (Root, "gamma"), "gamma");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Await_Ready;
      Files.Model.Set_Filter (Model, "alpha");
      Await_Refresh (False);
      Assert (Files.Model.Item_Count (Model) = 2 and then Files.Model.Visible_Count (Model) = 1,
              "a completed old read cannot overwrite a later model edit");
      Files.Model.Set_Filter (Model, "");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Await_Refresh (True);
      Assert (Files.Model.Item_Count (Model) = 3, "the next matching read includes the new file");

      Write_Binary_File (Join (Root, ".hidden"), "hidden");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Ready;
      Settings.Show_Hidden_Files := True;
      Await_Refresh (False);
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Refresh (True);
      Assert (Files.Model.Item_Count (Model) = 4, "settings changes reject old snapshots and apply a fresh read");
      Files.Model.Set_Error (Model, "error.trash.restore_exists");
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Refresh (True);
      Assert (Files.Model.Last_Error_Key (Model) = "error.trash.restore_exists",
              "a successful refresh preserves a mutation recovery error");

      Ada.Directories.Create_Directory (Join (Root, "other"));
      Step := Files.Operations.Refresh (Model, Settings);
      Await_Ready;
      Load := Files.File_System.Load_Directory (Join (Root, "other"), Settings);
      Files.Model.Navigate_To (Model, Join (Root, "other"), Load.Items);
      Await_Refresh (False);
      Assert (Files.Model.Item_Count (Model) = 0
              and then Files.Model.Current_Path (Model) = Join (Root, "other"),
              "navigation prevents an old directory snapshot from replacing the new view");
      Files.Settings.Note_Recent (Settings, Join (Root, "alpha"));
      Files.Model.Navigate_Recent (Model, Files.File_System.Item_Vectors.Empty_Vector);
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_F5, Current_Font_Size => 16, Result => Routed);
      Await_Refresh (True);
      Assert (Files.Model.In_Recent_View (Model) and then Files.Model.Item_Count (Model) = 1,
              "explicit Recent refresh also loads its items in a helper");
      Restore_Fault;
   exception
      when others =>
         Files.Refresh_Jobs.Cancel (Model);
         Restore_Fault;
         raise;
   end Test_Background_Refresh;
