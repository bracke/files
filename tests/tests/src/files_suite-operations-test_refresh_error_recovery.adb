separate (Files_Suite.Operations)
   procedure Test_Refresh_Error_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      View : constant String := Join (Root, "view");
      Held : constant String := Join (Root, "held");
      Signature : Files.File_System.Directory_Signature;

      procedure Await_Refresh (Expected_Reload : Boolean) is
         Applied : Boolean := False;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
            exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
         end loop;
         Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model))
                 and then Applied = Expected_Reload, "the matching refresh completes with the expected listing update");
      end Await_Refresh;

      procedure Start_Refresh (Manual : Boolean) is
      begin
         Step := (if Manual then Files.Operations.Refresh (Model, Settings)
                  else Files.Operations.Refresh_If_Changed (Model, Settings));
      end Start_Refresh;

      procedure Await_Ready is
         Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Model);
         Finished, Cancelled : Boolean;
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Process_Jobs.Poll (Job, Finished, Cancelled);
            exit when Finished;
         end loop;
         Assert (Finished and then not Cancelled, "the recovery snapshot is ready before a later error is recorded");
      end Await_Ready;
   begin
      for Background in Boolean loop
         for Manual in Boolean loop
            Reset_Root;
            Ada.Directories.Create_Path (View);
            Write_Binary_File (Join (View, "alpha"), "alpha");
            Load := Files.File_System.Load_Directory (View, Settings);
            Files.Model.Initialize (Model, View, Load.Items, Root);
            Files.Model.Set_Background_Transfers (Model, Background);
            Signature := Files.File_System.Directory_State (View);
            Files.Model.Set_Directory_Signature (Model, Signature);
            Select_Name (Model, "alpha");
            Ada.Directories.Rename (View, Held);
            for Retry in 1 .. 2 loop
               Start_Refresh (Manual);
               if Background then
                  Await_Refresh (False);
               else
                  Files_Suite.Support.Assert_Equal
                    (Step.Status,
                     Files.Operations.Operation_Failed,
                     "unavailable refresh fails synchronously");
               end if;
               Assert (Files.Model.Last_Error_Key (Model) = "error.directory.load"
                       and then Files.Model.Item_Count (Model) = 1,
                       "a repeated failed refresh retains the load error and displayed items");
            end loop;
            Ada.Directories.Rename (Held, View);
            Assert (not Files.File_System.Detect_Directory_Change (Signature, View).Changed,
                    "restoring the same directory leaves the previous signature unchanged");
            Start_Refresh (Manual);
            if Background then
               Files_Suite.Support.Assert_Equal
                 (Files.Model.Last_Error_Key (Model),
                  "error.directory.load",
                  "posting a retry retains the load error until success is confirmed");
               Await_Refresh (True);
            else
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "the synchronous recovery succeeds");
            end if;
            Assert (Files.Model.Last_Error_Key (Model) = "" and then Files.Model.Item_Count (Model) = 1
                    and then Files.Model.Selected_Name (Model) = "alpha",
                    "successful manual and automatic refreshes clear obsolete errors and preserve selection");
         end loop;
      end loop;
      Files.Model.Set_Background_Transfers (Model, True);
      for Manual in Boolean loop
         Files.Model.Set_Error (Model, "error.trash.restore_exists");
         Start_Refresh (Manual);
         Await_Refresh (Manual);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model),
            "error.trash.restore_exists",
            "changed and unchanged successful refreshes retain file operation errors");
      end loop;
      Files.Model.Set_Error (Model, "error.directory.load");
      Start_Refresh (False);
      Await_Ready;
      Files.Model.Set_Error (Model, "error.undo.failed");
      Await_Refresh (False);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.undo.failed",
         "an old successful recovery cannot erase a newer operation error");
      Files.Model.Set_Error (Model, "error.directory.load");
      Start_Refresh (True);
      Files.Refresh_Jobs.Cancel (Model);
      Await_Refresh (False);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.directory.load",
         "cancelling a retry does not clear an unconfirmed load error");
      Files.Settings.Note_Recent (Settings, Join (View, "alpha"));
      Files.Model.Navigate_Recent (Model, Files.File_System.Item_Vectors.Empty_Vector);
      for Operation_Error in Boolean loop
         Files.Model.Set_Error
           (Model, (if Operation_Error then "error.trash.restore_exists" else "error.directory.load"));
         Start_Refresh (True);
         Await_Refresh (True);
         Assert (Files.Model.In_Recent_View (Model) and then Files.Model.Item_Count (Model) = 1
                 and then Files.Model.Last_Error_Key (Model) =
                   (if Operation_Error then "error.trash.restore_exists" else ""),
                 "successful Recent refresh clears load errors while retaining operation errors");
      end loop;
   exception
      when others => Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Refresh_Error_Recovery;
