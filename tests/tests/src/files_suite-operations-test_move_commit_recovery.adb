with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   procedure Test_Move_Commit_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "inbox/entry");
      Remote : Files_Suite.Volumes.Remote_Directory;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Had_Fault : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TEST_TRANSFER_RESULT_LOSS");
      Old_Fault : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TRANSFER_RESULT_LOSS", "");
      procedure Restore is
      begin
         if Had_Fault then
            Ada.Environment_Variables.Set ("FILES_TEST_TRANSFER_RESULT_LOSS", Old_Fault);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_TRANSFER_RESULT_LOSS");
         end if;
      end Restore;
      procedure Cleanup is
      begin
         Restore;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
      end Cleanup;
   begin
      --  The same-device half runs everywhere; the cross-device half needs a
      --  second volume, and is counted as skipped where there is none.
      Remote.Create ("files-test-move-commit-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Move_Commit_Recovery", Files_Suite.Volumes.No_Other_Volume);
      end if;
      for Cross_Device in Boolean loop
         if not Cross_Device or else Remote.Path /= "" then
            declare
               Parent : constant String := (if Cross_Device then Remote.Path else Root);
               Dest : constant String := Join (Parent, "entry");
            begin
               for Replace in Boolean loop
                  Reset_Root;
                  Ada.Directories.Create_Directory (Join (Root, "inbox"));
                  Write_Binary_File (Source, "owned original");
                  if Ada.Directories.Exists (Dest) then
                     Mutation := Files.File_System.Delete_Permanently (Dest);
                     Assert (Mutation.Success, "clear the previous recovered destination");
                  end if;
                  if Replace then
                     Write_Binary_File (Dest, "original destination");
                  end if;
                  Load := Files.File_System.Load_Directory (Parent, Settings);
                  Files.Model.Initialize (Model, Parent, Load.Items, Parent);
                  Files.Model.Clear_Undo (Model);
                  Files.Model.Set_Background_Transfers (Model, True);
                  Actions.Clear;
                  Actions.Append (Files.Paste.Resolved_Action'
                    (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, Replace));
                  Ada.Environment_Variables.Set ("FILES_TEST_TRANSFER_RESULT_LOSS", "source-replacement");
                  Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
                  Step := Complete_Operation
                    (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
                  Await_View (Model, Settings);
                  Restore;
                  Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model)
                          and then File_Has_Bytes (Source, "unrelated replacement")
                          and then File_Has_Bytes (Dest, "owned original"),
                          "a committed move retains Undo despite lost results and a recreated source pathname: "
                          & Boolean'Image (Cross_Device) & Boolean'Image (Replace)
                          & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                          & " error=" & To_String (Step.Error_Key)
                          & " undo=" & Boolean'Image (Files.Model.Undo_Available (Model))
                          & " source=" & Boolean'Image (File_Has_Bytes (Source, "unrelated replacement"))
                          & " dest=" & Boolean'Image (File_Has_Bytes (Dest, "owned original")));
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model)
                          and then File_Has_Bytes (Source, "unrelated replacement")
                          and then File_Has_Bytes (Dest, "owned original"),
                          "recovered Undo preserves the new source occupant and remains retryable");
                  Mutation := Files.File_System.Delete_Permanently (Source);
                  Assert (Mutation.Success, "vacate our replacement fixture");
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Assert (Step.Status = Files.Operations.Operation_Success
                          and then File_Has_Bytes (Source, "owned original"),
                          "retry reverses the journaled committed move");
                  Assert ((if Replace then File_Has_Bytes (Dest, "original destination")
                           else not Ada.Directories.Exists (Dest)), "retry also restores a replaced destination");
               end loop;
            end;
         end if;
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Move_Commit_Recovery;
