with Files.Model.Jobs;
with Files.Operation_Commands;
with Files.Operation_Results;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Timing;
separate (Files_Suite.Recovery)
   --  A window that closes mid-job let its helper go by dropping it, and a
   --  dropped helper was killed at once: one halfway through a Replace never
   --  put the original back. The window now cancels it as the user's Cancel
   --  does, so the helper has its grace to see the cancel and finish
   --  cleanly. And a paste's progress -- the originals its Replaces
   --  preserved among it -- went with the paste, never reaching the history
   --  that sends them to the system trash as the window ends.
   procedure Test_A_Closing_Window_Cancels_Its_Job (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model       : aliased Files.Model.Window_Model;
      Paste       : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Watch       : Files.Refresh.Watch_Session;
      Load        : Files.File_System.Directory_Load_Result;
      Step        : Files.Operation_Results.Operation_Result;
      Seen        : constant String := Join (Root, "cancel-seen");
      Started     : Unbounded_String;
      Actions     : Files.Paste.Resolved_Action_Vectors.Vector;
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "FILES_TEST_STALL_OPERATIONS");
      Files_Suite.Support.Guards.Save (Environment, "FILES_TEST_CANCEL_SEEN");
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Guards.Save (Environment, "XDG_DATA_HOME");

      --  An operation helper, stalled in its work, sees the window's cancel.
      Reset_Root;
      Write_Binary_File (Join (Root, "victim.txt"), "victim bytes");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Select_Name (Model, "victim.txt");
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", "1");
      Ada.Environment_Variables.Set ("FILES_TEST_CANCEL_SEEN", Seen);
      Step := Files.Operation_Commands.Delete_Selected_Permanently (Model, Settings);
      Assert (Step.Status = Files.Operation_Results.Operation_Success
              and then Files.Model.Foreground_Job_Is_Active (Model), "the delete runs in a helper");
      Started := To_Unbounded_String (Files.Jobs.Process.Path (Files.Model.Jobs.Background_Operation (Model),
        "started"));
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Ada.Directories.Exists (To_String (Started));
      end loop;
      Assert (Ada.Directories.Exists (To_String (Started)), "the helper reaches its stalled work");
      Files.Application.Windows.Release_Window_Jobs (Model, Watch);
      Ada.Environment_Variables.Set ("FILES_TEST_STALL_OPERATIONS", "");
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Ada.Directories.Exists (Seen);
      end loop;
      Assert (Ada.Directories.Exists (Seen), "the closed window's helper is let see the cancel, not killed outright");
      Assert (File_Has_Bytes (Join (Root, "victim.txt"), "victim bytes"), "and the delete it was stalled in never ran");

      --  A paste that replaced an item, closed before its next item.
      Reset_Root;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "data"));
      Write_Binary_File (Join (Root, "new-one.txt"), "new");
      Write_Binary_File (Join (Root, "one.txt"), "old");
      Write_Binary_File (Join (Root, "new-two.txt"), "two");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, False);
      Files.Operations.Clear_Undo (Model);
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Join (Root, "new-one.txt")),
                         To_Unbounded_String (Join (Root, "one.txt")), False, True));
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Join (Root, "new-two.txt")),
                         To_Unbounded_String (Join (Root, "two.txt")), False, False));
      Files.Operations.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      Step := Files.Job_Drivers.Foreground.Advance (Model, Settings, 1);
      Assert (Step.Status = Files.Operation_Results.Operation_Success
              and then Files.Model.Foreground_Job_Is_Active (Model)
              and then File_Has_Bytes (Join (Root, "one.txt"), "new"),
              "the paste has replaced its first item and is still running");
      Files.Application.Windows.Release_Window_Jobs (Model, Watch);
      Assert (not Files.Model.Foreground_Job_Is_Active (Model), "the closing window lets the paste go");
      Assert (Files.Model.History.Undo_Available (Model),
              "with what it did recorded, the replaced original among it, for the history to settle");
   end Test_A_Closing_Window_Cancels_Its_Job;
