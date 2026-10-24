separate (Files_Suite.Operations)
   procedure Test_Transfer_Result_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Join (Root, "inbox"), "entry");
      Dest : constant String := Join (Root, "entry");
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
   begin
      for Mode in Files.File_System.Drop_Import_Mode loop
         for Replaced in Boolean loop
            for Fault in 1 .. 4 loop
               Reset_Root;
               Ada.Directories.Create_Directory (Join (Root, "inbox"));
               Write_Binary_File (Source, "source bytes");
               if Replaced then
                  Write_Binary_File (Dest, "original destination");
               end if;
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, True);
               Actions.Clear;
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, Replaced));
               Ada.Environment_Variables.Set ("FILES_TEST_TRANSFER_RESULT_LOSS",
                 (case Fault is when 1 => "missing", when 2 => "checkpoint", when 3 => "journal",
                  when others => "replacement"));
               Files.Model.Begin_Paste_Execution (Model, Actions, Mode, False);
               Step := Complete_Operation
                 (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model),
                       "an unavailable helper result reports failure but retains committed paste history: "
                       & Files.File_System.Drop_Import_Mode'Image (Mode) & Boolean'Image (Replaced)
                       & Integer'Image (Fault) & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                       & " error=" & To_String (Step.Error_Key)
                       & " undo=" & Boolean'Image (Files.Model.Undo_Available (Model)));
               Assert (Ada.Directories.Exists (Source) = (Mode = Files.File_System.Drop_Copy),
                       "recovery recognizes whether the source move committed");
               if Fault = 4 then
                  Assert (Files.Model.Undo_History (Model).Last_Element.Created_Identities.First_Element
                          = Files.File_Identities.Token (Dest & "-saved"),
                          "recovery retains the published identity without recapturing a replacement");
                  Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Await_View (Model, Settings);
                  Assert (Step.Status = Files.Operations.Operation_Failed
                          and then File_Has_Bytes (Dest, "unrelated replacement"),
                          "recovered history preserves an unrelated destination replacement");
                  Mutation := Files.File_System.Delete_Permanently (Dest);
                  Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Dest & "-saved", Dest),
                          "restore the published paste entry");
               end if;
               Restore;
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then File_Has_Bytes (Source, "source bytes"),
                       "Undo reverses a committed paste recovered without its final helper result");
               if Replaced then
                  Assert (File_Has_Bytes (Dest, "original destination"),
                          "recovered Undo restores the replacement backup");
               else
                  Assert (not Ada.Directories.Exists (Dest), "recovered Undo vacates the published destination");
               end if;
            end loop;
         end loop;
      end loop;
      Restore;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         Restore;
         raise;
   end Test_Transfer_Result_Recovery;
