separate (Files_Suite.Operations)
   procedure Test_Stalled_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Watch : Files.Refresh_Jobs.Watch_Session;
      Step : Files.Operations.Operation_Result;
      pragma Unreferenced (Step);
      Load : Files.File_System.Directory_Load_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Before : Ada.Calendar.Time;
      Had_Flag : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_STALL_READS");
      Old_Flag : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STALL_READS", "");

      procedure Cleanup is
      begin
         Files.Refresh_Jobs.Cancel (Model);
         Files.Refresh_Jobs.Release_Watch (Watch);
         if Had_Flag then
            Ada.Environment_Variables.Set ("FILES_TEST_STALL_READS", Old_Flag);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_STALL_READS");
         end if;
      end Cleanup;

      procedure Await_Stall is
         Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Model);
      begin
         for Attempt in Files_Suite.Support.Polling loop
            exit when Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "started"));
         end loop;
         Assert (Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "started")),
                 "the refresh helper has entered deliberately stalled filesystem work");
      end Await_Stall;
   begin
      Reset_Root;
      declare
         Oversized : constant String (1 .. 32 * 1024 + 1) :=
           [others => 'x'];
      begin
         Files.Refresh_Jobs.Watch_Path (Watch, "relative-watch");
         Files_Suite.Support.Assert_Equal
           (Files.Refresh_Jobs.Testing.Watch_Target (Watch),
            "",
            "a relative watch path is rejected before launching a helper");
         Files.Refresh_Jobs.Watch_Path (Watch, Oversized);
         Files_Suite.Support.Assert_Equal
           (Files.Refresh_Jobs.Testing.Watch_Target (Watch),
            "",
            "an oversized watch path falls back without launching a doomed helper");
      end;
      declare
         Directory : constant String := Join (Root, "watch-notifications");
         Changed   : constant String := Join (Directory, "changed");
         Claimed   : constant String := Join (Directory, "changed.claimed");
         Temporary : constant String := Join (Directory, "changed.tmp");
      begin
         Ada.Directories.Create_Directory (Directory);
         Write_Binary_File (Changed, "");
         Assert
           (Files.Refresh_Jobs.Testing.Claim_Notification (Directory)
            and then not Ada.Directories.Exists (Changed)
            and then Ada.Directories.Exists (Claimed),
            "watch polling atomically claims the notification being acknowledged");
         Write_Binary_File (Changed, "");
         Ada.Directories.Delete_File (Claimed);
         Assert
           (Files.Refresh_Jobs.Testing.Claim_Notification (Directory),
            "a notification published after the claim remains for the next poll");
         Ada.Directories.Delete_File (Claimed);
         Ada.Directories.Create_Directory (Temporary);
         Assert
           (not Files.Refresh_Jobs.Testing.Post_Notification (Directory),
            "a watch marker reports a transient publication failure");
         Ada.Directories.Delete_Directory (Temporary);
         Assert
           (Files.Refresh_Jobs.Testing.Post_Notification (Directory)
            and then Ada.Directories.Exists (Changed),
            "a consumed watch event can be published on a later retry");
         Ada.Directories.Delete_File (Changed);
         Ada.Directories.Delete_Directory (Directory);
      end;
      Write_Binary_File (Join (Root, "source"), "source");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_READS", "1");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Files.Refresh_Jobs.Watch_Path (Watch, Root);
      Await_Stall;
      Before := Ada.Calendar.Clock;
      for Attempt in 1 .. 100 loop
         Assert (not Files.Refresh_Jobs.Advance (Model, Settings), "stalled reads leave the current listing intact");
         Assert (not Files.Refresh_Jobs.Poll_Watch (Watch), "watch polling never waits for registration or I/O");
      end loop;
      Assert (Ada.Calendar.Clock - Before < Prompt_Limit,
              "repeated UI polls return promptly while helpers are stalled");
      Files.Model.Set_Filter (Model, "source");
      Assert (not Files.Refresh_Jobs.Advance (Model, Settings)
              and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "a model edit cancels even a refresh that cannot finish");
      Step := Files.Operations.Refresh_If_Changed (Model, Settings);
      Await_Stall;
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Join (Root, "source")),
                         To_Unbounded_String (Join (Root, "dest")), False, False));
      Before := Ada.Calendar.Clock;
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "starting paste immediately releases an outstanding read");
      Files.Operations.Cancel_Paste_Execution (Model);
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
      Assert (Ada.Calendar.Clock - Before < Prompt_Limit
              and then not Files.Model.Paste_Execution_Is_Active (Model)
              and then not Ada.Directories.Exists (Join (Root, "dest")),
              "paste cancellation finalizes promptly without waiting for a directory reload");
      Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "paste finalization schedules its directory refresh independently");
      Await_Stall;
      Before := Ada.Calendar.Clock;
      Cleanup;
      Assert (Ada.Calendar.Clock - Before < Prompt_Limit
              and then not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "window cleanup releases stalled refresh and native-watch helpers without waiting");
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Stalled_Refresh;
