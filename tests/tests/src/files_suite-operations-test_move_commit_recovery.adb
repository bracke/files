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
      procedure Cleanup is
      begin
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
                  declare
                     --  The fault is injected for this move only; the guard
                     --  puts the variable back before the Undo, on failure too.
                     Fault : Files_Suite.Support.Environment_Guard;
                  begin
                     Files_Suite.Support.Save (Fault, "FILES_TEST_TRANSFER_RESULT_LOSS");
                     Ada.Environment_Variables.Set ("FILES_TEST_TRANSFER_RESULT_LOSS", "source-replacement");
                     Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
                     Step := Complete_Operation
                       (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
                     Await_View (Model, Settings);
                  end;
                  declare
                     Committed : constant String :=
                       "a committed move retains Undo despite lost results and a recreated source pathname: "
                       & Boolean'Image (Cross_Device) & Boolean'Image (Replace)
                       & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                       & " error=" & To_String (Step.Error_Key)
                       & " undo=" & Boolean'Image (Files.Model.Undo_Available (Model))
                       & " source=" & Boolean'Image (File_Has_Bytes (Source, "unrelated replacement"))
                       & " dest=" & Boolean'Image (File_Has_Bytes (Dest, "owned original"));
                  begin
                     Assert (Step.Status = Files.Operations.Operation_Failed, Committed & " (the move fails)");
                     Assert (Files.Model.Undo_Available (Model), Committed & " (Undo retained)");
                     Assert (File_Has_Bytes (Source, "unrelated replacement"),
                             Committed & " (source replacement kept)");
                     Assert (File_Has_Bytes (Dest, "owned original"), Committed & " (destination holds the original)");
                  end;
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Files_Suite.Support.Assert_Equal
                    (Step.Status,
                     Files.Operations.Operation_Failed,
                     "recovered Undo preserves the new source occupant and remains retryable: the Undo fails");
                  Assert (Files.Model.Undo_Available (Model),
                          "recovered Undo preserves the new source occupant and remains retryable: Undo retained");
                  Assert (File_Has_Bytes (Source, "unrelated replacement"),
                          "recovered Undo preserves the new source occupant and remains retryable: source kept");
                  Assert (File_Has_Bytes (Dest, "owned original"),
                          "recovered Undo preserves the new source occupant and remains retryable: destination kept");
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
