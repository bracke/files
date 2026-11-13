with Files.Durability.Testing;
with Files.Items;
with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   --  A cross-device move whose source could not be removed, and whose copy
   --  then could not be removed either, keeps both: its undo deletes the copy
   --  and leaves the source, instead of moving the copy back onto it.
   procedure Test_Failed_Move_Kept_Copy_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Remote   : Files_Suite.Volumes.Remote_Directory;
      Source   : constant String := Join (Root, "kept-source");
      function Dest return String is (Join (Remote.Path, "kept-destination"));
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Model    : Files.Model.Window_Model;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Step     : Files.Operations.Operation_Result;

      procedure Cleanup is
      begin
         Files.Durability.Testing.Clear;
         Ada.Environment_Variables.Set ("FILES_TEST_STAGE_SYNC_FAULT", "");
         Files.Model.Clear_Paste_Execution (Model);
      end Cleanup;
   begin
      Reset_Root;
      Remote.Create ("files-test-kept-copy-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Failed_Move_Kept_Copy_Undo", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Files_Suite.Support.Save (Environment, "FILES_TEST_STAGE_SYNC_FAULT");
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, False));
      for Background in Boolean loop
         Reset_Root;
         Write_Binary_File (Source, "the bytes");
         Files.Model.Initialize (Model, Remote.Path, Files.Items.Item_Vectors.Empty_Vector, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         --  Every recovery stage holding its payload fails its flush: the
         --  source cannot be set aside for removal and is put back, and the
         --  copy cannot be set aside for deletion either, so it stays.
         Files.Durability.Testing.Fail_Stage_Sync;
         Ada.Environment_Variables.Set ("FILES_TEST_STAGE_SYNC_FAULT", "1");
         Files.Operations.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move);
         for Attempt in Files_Suite.Support.Polling loop
            Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
            exit when not Files.Model.Paste_Execution_Is_Active (Model);
         end loop;
         Cleanup;
         Assert (Step.Status = Files.Operations.Operation_Failed,
                 "the move fails, background " & Background'Image);
         Assert (File_Has_Bytes (Source, "the bytes"), "the source stays, background " & Background'Image);
         Assert (File_Has_Bytes (Dest, "the bytes"), "the copy is kept, background " & Background'Image);
         Assert (Files.Model.Undo_Available (Model), "the kept copy can be undone, background " & Background'Image);

         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Assert (Step.Status = Files.Operations.Operation_Success,
                 "undoing the kept copy succeeds, background " & Background'Image);
         Assert (not Ada.Directories.Exists (Dest), "undo deletes the copy, background " & Background'Image);
         Assert (File_Has_Bytes (Source, "the bytes"),
                 "undo leaves the source as it was, background " & Background'Image);
         Await_View (Model, Settings);
      end loop;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Failed_Move_Kept_Copy_Undo;
