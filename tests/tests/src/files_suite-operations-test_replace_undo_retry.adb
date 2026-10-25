separate (Files_Suite.Operations)
   procedure Test_Replace_Undo_Retry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      type Scenario_Kind is (Copy_Replace, Move_Replace, Recovery_Only);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      for Native in Boolean loop
         for Scenario in Scenario_Kind loop
            Reset_Root;
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "retry-trash"));
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", (if Native then "windows" else "xdg"));
            declare
               Dest_A : constant String := Join (Root, "retry-dest-a");
               Dest_B : constant String := Join (Root, "retry-dest-b");
               Source_A : constant String := Join (Root, "retry-source-a");
               Source_B : constant String := Join (Root, "retry-source-b");
               Back_A, Back_B : Files.Types.UString;
               From_Paths, To_Paths, Backups : Files.Types.String_Vectors.Vector;
               Model : Files.Model.Window_Model;
               Step : Files.Operations.Operation_Result;
               Mutation : Files.File_System.Mutation_Result;
            begin
               Write_Binary_File (Dest_A, "original A");
               Write_Binary_File (Dest_B, "original B");
               Mutation := Files.File_System.Preserve_For_Replace (Dest_A, Back_A);
               Assert (Mutation.Success, "preserve the first replacement original");
               Mutation := Files.File_System.Preserve_For_Replace (Dest_B, Back_B);
               Assert (Mutation.Success, "preserve the second replacement original");
               Backups.Append (Back_A);
               Backups.Append (Back_B);
               if Scenario /= Recovery_Only then
                  Write_Binary_File (Dest_A, "new A");
                  Write_Binary_File (Dest_B, "new B");
                  From_Paths.Append (To_Unbounded_String (Dest_A));
                  From_Paths.Append (To_Unbounded_String (Dest_B));
                  if Scenario = Move_Replace then
                     To_Paths.Append (To_Unbounded_String (Source_A));
                     To_Paths.Append (To_Unbounded_String (Source_B));
                  end if;
               end if;
               Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
               if Scenario = Recovery_Only then
                  Files.Model.Record_Undo
                    (Model, Files.Model.Undo_Restore_Trash, Backups, To_Paths, Redoable => False);
               else
                  Files.Model.Record_Undo
                    (Model,
                     (if Scenario = Move_Replace then Files.Model.Undo_Move else Files.Model.Undo_Delete_Created),
                     From_Paths, To_Paths, Redoable => False, Restore_Trash => Backups);
               end if;
               declare
                  Held : constant String := Join (Ada.Directories.Containing_Directory (To_String (Back_B)),
                                                  "held-payload");
               begin
                  --  Make the second backup unavailable without OS-specific permission assumptions.
                  Assert (Hostkit.Fs.Move_No_Replace (To_String (Back_B), Held), "temporarily block one restore");
                  for Attempt in 1 .. 2 loop
                     Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                     Assert (Step.Status = Files.Operations.Operation_Failed
                             and then Files.Model.Undo_Available (Model),
                             "an unfinished restore stays available for another Undo attempt");
                     Assert (File_Has_Bytes (Dest_A, "original A"),
                             "a failed Undo retry never deletes or relocates an already-restored original");
                     Assert (File_Has_Bytes (Held, "original B"), "the blocked original remains recoverable");
                     if Scenario = Move_Replace then
                        Assert (File_Has_Bytes (Source_A, "new A") and then File_Has_Bytes (Source_B, "new B"),
                                "a replacement move is reversed once while original restores are retried");
                     end if;
                  end loop;
                  Assert (Hostkit.Fs.Move_No_Replace (Held, To_String (Back_B)), "unblock the remaining restore");
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
                  Files_Suite.Support.Assert_Equal
                    (Step.Status,
                     Files.Operations.Operation_Success,
                     "Undo completes after the remaining original becomes available");
                  Assert (File_Has_Bytes (Dest_A, "original A") and then File_Has_Bytes (Dest_B, "original B"),
                          "all originals survive the successful retry");
                  Assert (not Files.Model.Undo_Available (Model) and then not Files.Model.Redo_Available (Model),
                          "the completed replacement recovery consumes its Undo-only entry");
               end;
            end;
         end loop;
      end loop;
   end Test_Replace_Undo_Retry;
