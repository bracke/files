separate (Files_Suite.Operations)
   procedure Test_Publication_Journal_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      for Via_Helper in Boolean loop
         for Mode in Files.File_System.Drop_Import_Mode loop
            for Replaced in Boolean loop
               Reset_Root;
               declare
                  Source : constant String := Join (Root, "journal-source");
                  Dest : constant String := Join (Root, "journal-dest");
                  Transport : constant String := Join (Root, "journal-transport");
                  Action : constant Files.Paste.Resolved_Action :=
                    (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, Replaced);
                  Actions : Files.Paste.Resolved_Action_Vectors.Vector;
                  Model : Files.Model.Window_Model;
                  Step : Files.Operations.Operation_Result;
                  Outcome : Files.Transfer_Jobs.Job_Result;
               begin
                  Write_Binary_File (Source, "source bytes");
                  if Replaced then
                     Write_Binary_File (Dest, "original bytes");
                  end if;
                  --  Refuse journal writes while keeping result transport usable.
                  Ada.Directories.Create_Path (Join (Transport, "created"));
                  Files.Job_Context.Initialize (Transport);
                  if Via_Helper then
                     Files.Transfer_Jobs.Testing.Write_Request
                       (Join (Transport, "request"), Action, Mode);
                     Files.Transfer_Jobs.Run_Helper (Transport);
                     Outcome := Files.Transfer_Jobs.Testing.Read_Result
                       (Join (Transport, "result"));
                     Assert
                       (Outcome.Mutation.Success,
                        "the helper acknowledges a committed mutation despite a journal failure: success");
                     Assert
                       (not Outcome.Cancelled,
                        "the helper acknowledges a committed mutation despite a journal failure: not cancelled");
                     Files_Suite.Support.Assert_Equal
                       (Length (Outcome.Mutation.Error_Key),
                        0,
                        "the helper acknowledges a committed mutation despite a journal failure: no error key");
                     Assert (Length (Outcome.Created_Identity) > 0
                             and then Outcome.Created_Identity = Files.File_Identities.Token (Dest),
                             "the helper result retains ownership without a publication journal");
                     if Replaced then
                        Assert (Length (Outcome.Trashed) > 0
                                and then File_Has_Bytes (To_String (Outcome.Trashed), "original bytes"),
                                "the successful helper result retains the replacement original for Undo");
                     end if;
                  else
                     Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
                     Actions.Append (Action);
                     Files.Model.Begin_Paste_Execution (Model, Actions, Mode);
                     Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
                     Files_Suite.Support.Assert_Equal
                       (Step.Status,
                        Files.Operations.Operation_Success,
                        "paste completion reports the committed mutation accurately: status");
                     Assert
                       (not Files.Model.Paste_Execution_Is_Active (Model),
                        "paste completion reports the committed mutation accurately: paste finished");
                     Files_Suite.Support.Assert_Equal
                       (Files.Model.Last_Error_Key (Model),
                        "",
                        "paste completion reports the committed mutation accurately: no error");
                     Assert (Files.Model.Undo_Available (Model),
                             "paste still records Undo when the publication journal is unavailable");
                  end if;
                  Assert (File_Has_Bytes (Dest, "source bytes"), "the completed destination retains all source bytes");
                  Files_Suite.Support.Assert_Equal
                    (Ada.Directories.Exists (Source),
                     (Mode = Files.File_System.Drop_Copy),
                     "a committed move removes its source while a copy preserves it");
                  if Mode = Files.File_System.Drop_Copy then
                     Assert (not Ada.Directories.Exists (Join (Root, ".files-work-1")),
                             "a journal failure does not retain copy staging or remove the published output");
                  end if;
                  Files.Job_Context.Initialize ("");
                  if not Via_Helper then
                     Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                     Assert (Step.Status = Files.Operations.Operation_Success
                             and then File_Has_Bytes (Source, "source bytes"),
                             "Undo reverses the committed operation without losing the source bytes");
                     if Replaced then
                        Assert (File_Has_Bytes (Dest, "original bytes"),
                                "replacement Undo restores the retained original after journal failure");
                     else
                        Assert (not Ada.Directories.Exists (Dest), "Undo vacates the created destination");
                     end if;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
   exception
      when others =>
         Files.Job_Context.Initialize ("");
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Publication_Journal_Failure;
