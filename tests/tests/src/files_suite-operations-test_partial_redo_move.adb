separate (Files_Suite.Operations)
   procedure Test_Partial_Redo_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source_A : constant String := Join (Root, "redo-move-source-a");
      Source_B : constant String := Join (Root, "redo-move-source-b");
      Dest_A : constant String := Join (Root, "redo-move-dest-a");
      Dest_B : constant String := Join (Root, "redo-move-dest-b");
      Saved_A : constant String := Join (Root, "saved-redo-move-dest-a");
      type Scenario_Kind is (Move_Action, Rename_Action);
   begin
      for Scenario in Scenario_Kind loop
         Reset_Root;
         declare
            Model : Files.Model.Window_Model;
            Step : Files.Operations.Operation_Result;
            Destinations, Sources : Files.Types.String_Vectors.Vector;
         begin
            Write_Binary_File (Dest_A, "original a");
            Write_Binary_File (Dest_B, "original b");
            Destinations.Append (To_Unbounded_String (Dest_A));
            Destinations.Append (To_Unbounded_String (Dest_B));
            Sources.Append (To_Unbounded_String (Source_A));
            Sources.Append (To_Unbounded_String (Source_B));
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Record_Undo
              (Model, (if Scenario = Move_Action then Files.Model.Undo_Move else Files.Model.Undo_Rename),
               Destinations, Sources);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success, "prepare a two-item move or rename Redo");
            Write_Binary_File (Dest_B, "unrelated collision");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Failed and then File_Has_Bytes (Dest_A, "original a")
                    and then not Ada.Directories.Exists (Source_A), "the first forward move completes before B fails");
            Write_Binary_File (Source_A, "unrelated new source");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then File_Has_Bytes (Source_A, "unrelated new source")
                    and then File_Has_Bytes (Dest_A, "original a")
                    and then File_Has_Bytes (Dest_B, "unrelated collision"),
                    "repeated partial Redo leaves completed moves and unrelated paths intact");
            Ada.Directories.Rename (Dest_A, Saved_A);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then not Ada.Directories.Exists (Dest_A)
                    and then File_Has_Bytes (Source_A, "unrelated new source")
                    and then Files.Model.Redo_Available (Model),
                    "a missing completed move invalidates its marker without moving a replacement source");
            Ada.Directories.Rename (Saved_A, Dest_A);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then File_Has_Bytes (Dest_A, "original a")
                    and then Files.Model.Redo_Available (Model),
                    "restoring the moved entry makes its invalidated marker retryable");
            Ada.Directories.Delete_File (Dest_B);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then Files.Model.Undo_Available (Model) and then not Files.Model.Redo_Available (Model)
                    and then File_Has_Bytes (Source_A, "unrelated new source")
                    and then File_Has_Bytes (Dest_B, "original b"),
                    "unblocking B completes Redo without moving the unrelated recreated source A");
            Ada.Directories.Delete_File (Source_A);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then File_Has_Bytes (Source_A, "original a") and then File_Has_Bytes (Source_B, "original b"),
                    "Undo reverses both moves after a recovered Redo");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then File_Has_Bytes (Dest_A, "original a") and then File_Has_Bytes (Dest_B, "original b")
                    and then not Ada.Directories.Exists (Source_A) and then not Ada.Directories.Exists (Source_B),
                    "a fresh Redo cycle moves both items after its progress was cleared");
         end;
      end loop;
   end Test_Partial_Redo_Move;
