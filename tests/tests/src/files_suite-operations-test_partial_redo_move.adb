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
            Files.Operations.Record_Undo
              (Model,
               (case Scenario is
                   when Move_Action   => Files.Model.Undo_Move,
                   when Rename_Action => Files.Model.Undo_Rename),
               Destinations, Sources);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "prepare a two-item move or rename Redo");
            Write_Binary_File (Dest_B, "unrelated collision");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Failed,
               "the first forward move completes before B fails: status");
            Assert (File_Has_Bytes (Dest_A, "original a"), "the first forward move completes before B fails: A moved");
            Assert
              (not Ada.Directories.Exists (Source_A),
               "the first forward move completes before B fails: A source vacated");
            Write_Binary_File (Source_A, "unrelated new source");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Failed,
               "repeated partial Redo leaves completed moves and unrelated paths intact: status");
            Assert
              (File_Has_Bytes (Source_A, "unrelated new source"),
               "repeated partial Redo leaves completed moves and unrelated paths intact: new source A intact");
            Assert
              (File_Has_Bytes (Dest_A, "original a"),
               "repeated partial Redo leaves completed moves and unrelated paths intact: moved A intact");
            Assert
              (File_Has_Bytes (Dest_B, "unrelated collision"),
               "repeated partial Redo leaves completed moves and unrelated paths intact: B collision intact");
            Ada.Directories.Rename (Dest_A, Saved_A);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Failed,
               "a missing completed move invalidates its marker without moving a replacement source: status");
            Assert
              (not Ada.Directories.Exists (Dest_A),
               "a missing completed move invalidates its marker without moving a replacement source"
               & ": moved A stays missing");
            Assert
              (File_Has_Bytes (Source_A, "unrelated new source"),
               "a missing completed move invalidates its marker without moving a replacement source"
               & ": new source A intact");
            Assert
              (Files.Model.Redo_Available (Model),
               "a missing completed move invalidates its marker without moving a replacement source: redo available");
            Ada.Directories.Rename (Saved_A, Dest_A);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Failed,
               "restoring the moved entry makes its invalidated marker retryable: status");
            Assert
              (File_Has_Bytes (Dest_A, "original a"),
               "restoring the moved entry makes its invalidated marker retryable: A restored");
            Assert
              (Files.Model.Redo_Available (Model),
               "restoring the moved entry makes its invalidated marker retryable: redo available");
            Ada.Directories.Delete_File (Dest_B);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "unblocking B completes Redo without moving the unrelated recreated source A: status");
            Assert
              (Files.Model.Undo_Available (Model),
               "unblocking B completes Redo without moving the unrelated recreated source A: undo available");
            Assert
              (not Files.Model.Redo_Available (Model),
               "unblocking B completes Redo without moving the unrelated recreated source A: redo consumed");
            Assert
              (File_Has_Bytes (Source_A, "unrelated new source"),
               "unblocking B completes Redo without moving the unrelated recreated source A: new source A intact");
            Assert
              (File_Has_Bytes (Dest_B, "original b"),
               "unblocking B completes Redo without moving the unrelated recreated source A: B moved");
            Ada.Directories.Delete_File (Source_A);
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Undo reverses both moves after a recovered Redo: status");
            Assert (File_Has_Bytes (Source_A, "original a"), "Undo reverses both moves after a recovered Redo: A back");
            Assert (File_Has_Bytes (Source_B, "original b"), "Undo reverses both moves after a recovered Redo: B back");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "a fresh Redo cycle moves both items after its progress was cleared: status");
            Assert
              (File_Has_Bytes (Dest_A, "original a"),
               "a fresh Redo cycle moves both items after its progress was cleared: A moved");
            Assert
              (File_Has_Bytes (Dest_B, "original b"),
               "a fresh Redo cycle moves both items after its progress was cleared: B moved");
            Assert
              (not Ada.Directories.Exists (Source_A),
               "a fresh Redo cycle moves both items after its progress was cleared: A source vacated");
            Assert
              (not Ada.Directories.Exists (Source_B),
               "a fresh Redo cycle moves both items after its progress was cleared: B source vacated");
         end;
      end loop;
   end Test_Partial_Redo_Move;
