separate (Files_Suite.Operations)
   procedure Test_Recovery_Entry_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Source : constant String := Join (Root, "original");
      Dest : constant String := Join (Root, "original (copy)");
      Saved : constant String := Join (Root, "saved-original");
      Load : Files.File_System.Directory_Load_Result;
      Finished, Cancelled : Boolean;
      Mutation : Files.File_System.Mutation_Result;
      Destinations, Sources, Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
      File : Ada.Streams.Stream_IO.File_Type;
      Had_Fault : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_LOST_CREATION_METADATA");
      Old_Fault : constant String := Ada.Environment_Variables.Value ("FILES_TEST_LOST_CREATION_METADATA", "");
      procedure Restore is
      begin
         if Had_Fault then
            Ada.Environment_Variables.Set ("FILES_TEST_LOST_CREATION_METADATA", Old_Fault);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_LOST_CREATION_METADATA");
         end if;
      end Restore;
   begin
      for Redo_Recovery in Boolean loop
         Reset_Root;
         Write_Binary_File (Source, "owned bytes");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, False);
         Select_Name (Model, "original");
         if Redo_Recovery then
            Step := Files.Operations.Duplicate_Selected (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "prepare redoable creation");
            Step := Files.Operations.Undo_Last (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "prepare Redo recovery");
         end if;
         Files.Model.Set_Background_Transfers (Model, True);
         Ada.Environment_Variables.Set ("FILES_TEST_LOST_CREATION_METADATA", "1");
         Step := (if Redo_Recovery then Files.Operations.Redo_Last (Model, Settings)
                  else Files.Operations.Duplicate_Selected (Model, Settings));
         declare
            Job : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Model);
         begin
            for Attempt in Files_Suite.Support.Polling loop
               Files.Process_Jobs.Poll (Job, Finished, Cancelled);
               exit when Finished;
            end loop;
            Assert (Finished and then Ada.Directories.Exists (Dest), "the helper published before metadata failure");
            if Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "history")) then
               Ada.Directories.Delete_File (Files.Process_Jobs.Path (Job, "history"));
            end if;
            Ada.Directories.Create_Directory (Files.Process_Jobs.Path (Job, "history"));
            Assert (Hostkit.Fs.Move_No_Replace (Dest, Saved), "retain the published entry");
            Write_Binary_File (Dest, "unrelated replacement");
            Restore;
            Step := Complete_Operation (Model, Settings, Step);
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed, "lost final metadata reports failure");
            if Redo_Recovery then
               Assert (Files.Model.Redo_Available (Model), "the interrupted Redo is retryable");
               Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then File_Has_Bytes (Dest, "unrelated replacement")
                       and then Files.Model.Redo_Available (Model),
                       "retry rejects a replacement behind the recovered completion marker");
               Mutation := Files.File_System.Delete_Permanently (Dest);
               Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved, Dest),
                       "restore the helper's completed publication for retry");
               Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success,
                       "retry accepts the restored verified publication");
               Assert (Hostkit.Fs.Move_No_Replace (Dest, Saved),
                       "retain the verified publication for the Undo replacement check");
               Write_Binary_File (Dest, "unrelated replacement");
            end if;
            declare
               Recorded : constant String :=
                 (if Files.Model.Undo_Available (Model)
                    and then not Files.Model.Undo_History (Model).Last_Element.Created_Identities.Is_Empty
                  then To_String (Files.Model.Undo_History (Model).Last_Element.Created_Identities.First_Element)
                  else "<none>");
            begin
               Assert (Files.Model.Undo_Available (Model)
                       and then Recorded = Files.File_Identities.Token (Saved),
                       "recovery uses the journaled original identity: redo="
                       & Boolean'Image (Redo_Recovery) & " recorded=[" & Recorded
                       & "] saved=[" & Files.File_Identities.Token (Saved) & "]");
            end;
         end;
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed
                 and then File_Has_Bytes (Dest, "unrelated replacement"),
                 "recovered Undo refuses to delete the replacement");
         Mutation := Files.File_System.Delete_Permanently (Dest);
         Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Saved, Dest), "restore the owned output");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success, "recovery remains undoable for its owned output");
      end loop;
      declare
         Journal_Directory : constant String := Join (Root, "linked-created-journal");
         Victim            : constant String := Join (Root, "linked-created-victim");
         Journal           : constant String := Join (Journal_Directory, "created");
      begin
         Ada.Directories.Create_Directory (Journal_Directory);
         Write_Binary_File (Victim, "protected recovery journal");
         if Hostkit.Fs.Create_Hard_Link (Victim, Journal) then
            Files.Job_Context.Initialize (Journal_Directory);
            Files.Job_Context.Record_Created (Source);
            Files.Job_Context.Initialize ("");
            Files.Job_Context.Read_Created
              (Journal_Directory, Destinations, Sources, Identities,
               Tree_Revisions);
            Assert
              (Project_Tools.Files.Read_Raw_File (Victim) =
                 "protected recovery journal"
               and then Destinations.Is_Empty
               and then Identities.Is_Empty,
               "created journal I/O refuses a multiply-linked file");
         end if;
      end;
      Ada.Directories.Create_Directory (Join (Root, "journal"));
      Files.Job_Context.Initialize (Join (Root, "journal"));
      Files.Job_Context.Record_Created (Source);
      Files.Job_Context.Initialize ("");
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.Append_File, Join (Join (Root, "journal"), "created"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "truncated destination");
      Ada.Streams.Stream_IO.Close (File);
      Files.Job_Context.Read_Created
        (Join (Root, "journal"), Destinations, Sources, Identities, Tree_Revisions);
      Assert (Natural (Destinations.Length) = 1 and then Natural (Identities.Length) = 1,
              "a truncated journal ignores incomplete records without losing earlier snapshots");
      --  Leases are created hidden on Windows, and Windows refuses to create
      --  over a hidden file, so each rewrite removes the journal first.
      Ada.Directories.Delete_File (Join (Join (Root, "journal"), "created"));
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Join (Join (Root, "journal"), "created"));
      Ada.Streams.Stream_IO.Set_Index
        (File, Ada.Streams.Stream_IO.Count (64 * 1024 * 1024 + 1));
      Character'Write (Ada.Streams.Stream_IO.Stream (File), 'x');
      Ada.Streams.Stream_IO.Close (File);
      Files.Job_Context.Read_Created
        (Join (Root, "journal"), Destinations, Sources, Identities, Tree_Revisions);
      Assert
        (Destinations.Is_Empty and then Sources.Is_Empty and then Identities.Is_Empty
         and then Tree_Revisions.Is_Empty,
         "an oversized recovery journal is rejected before allocating records");
      Ada.Directories.Delete_File (Join (Join (Root, "journal"), "created"));
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File,
         Join (Join (Root, "journal"), "created"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "files-created-3");
      String'Output (Ada.Streams.Stream_IO.Stream (File), "relative-destination");
      String'Output (Ada.Streams.Stream_IO.Stream (File), "");
      String'Output (Ada.Streams.Stream_IO.Stream (File), "identity");
      String'Output (Ada.Streams.Stream_IO.Stream (File), "revision");
      Ada.Streams.Stream_IO.Close (File);
      Files.Job_Context.Read_Created
        (Join (Root, "journal"), Destinations, Sources, Identities,
         Tree_Revisions);
      Assert
        (Destinations.Is_Empty and then Sources.Is_Empty
         and then Identities.Is_Empty and then Tree_Revisions.Is_Empty,
         "created recovery records reject relative destination paths");
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File,
         Join (Join (Root, "journal"), "moved"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), "files-moved-1");
      String'Output (Ada.Streams.Stream_IO.Stream (File), Source);
      String'Output (Ada.Streams.Stream_IO.Stream (File), "relative-source");
      String'Output (Ada.Streams.Stream_IO.Stream (File), "identity");
      Ada.Streams.Stream_IO.Close (File);
      Files.Job_Context.Read_Moved
        (Join (Root, "journal"), Destinations, Sources, Identities);
      Assert
        (Destinations.Is_Empty and then Sources.Is_Empty
         and then Identities.Is_Empty,
         "moved recovery records reject relative source paths");
      Files.Job_Context.Read_Created
        ("relative-recovery-journal", Destinations, Sources, Identities,
         Tree_Revisions);
      Assert
        (Destinations.Is_Empty and then Sources.Is_Empty
         and then Identities.Is_Empty and then Tree_Revisions.Is_Empty,
         "recovery journal readers reject relative transport directories");
      Ada.Directories.Delete_File (Join (Join (Root, "journal"), "created"));
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Join (Join (Root, "journal"), "created"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), Source);
      String'Output (Ada.Streams.Stream_IO.Stream (File), "old source");
      Ada.Streams.Stream_IO.Close (File);
      Files.Job_Context.Read_Created
        (Join (Root, "journal"), Destinations, Sources, Identities, Tree_Revisions);
      Assert (Destinations.Is_Empty and then Identities.Is_Empty, "identity-free legacy journals fail closed");
      Restore;
   exception
      when others =>
         Files.Job_Context.Initialize ("");
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         Restore;
         raise;
   end Test_Recovery_Entry_Identity;
