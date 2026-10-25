separate (Files_Suite.Operations)
   procedure Test_Partial_Redo_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Model.Undo_Create_Kind;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source_A : constant String := Join (Root, "redo-source-a");
      Source_B : constant String := Join (Root, "redo-source-b");
      Dest_A : constant String := Join (Root, "redo-dest-a");
      Dest_B : constant String := Join (Root, "redo-dest-b");
      Held_A : constant String := Join (Root, "held-a");
      Held_B : constant String := Join (Root, "held-b");
      Saved_A : constant String := Join (Root, "saved-redo-dest-a");
   begin
      for Kind in Files.Model.Create_Copy .. Files.Model.Create_Hard_Link loop
         for Missing_Source in Boolean loop
            Reset_Root;
            declare
               Model : Files.Model.Window_Model;
               Step : Files.Operations.Operation_Result;
               Destinations, Sources : Files.Types.String_Vectors.Vector;

               function Create (Source, Dest : String) return Boolean is
               begin
                  return
                    (case Kind is
                        when Files.Model.Create_Copy => Files.File_System.Copy_Tree (Source, Dest).Success,
                        when Files.Model.Create_Symbolic_Link =>
                          Files.File_System.Create_Symbolic_Link (Source, Dest).Success,
                        when Files.Model.Create_Hard_Link => Files.File_System.Create_Hard_Link (Source, Dest).Success);
               end Create;
            begin
               Write_Binary_File (Source_A, "original a");
               Write_Binary_File (Source_B, "original b");
               Assert (Create (Source_A, Dest_A) and then Create (Source_B, Dest_B), "prepare two created items");
               Destinations.Append (To_Unbounded_String (Dest_A));
               Destinations.Append (To_Unbounded_String (Dest_B));
               Sources.Append (To_Unbounded_String (Source_A));
               Sources.Append (To_Unbounded_String (Source_B));
               Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
               Files.Operations.Record_Undo
                 (Model, Files.Model.Undo_Delete_Created, Destinations,
                  Files.Types.String_Vectors.Empty_Vector, Forward => Sources, Create_Kind => Kind);
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "Undo removes both creations before Redo");
               if Missing_Source then
                  Ada.Directories.Rename (Source_B, Held_B);
               else
                  Write_Binary_File (Dest_B, "unrelated collision");
               end if;
               for Attempt in 1 .. 2 loop
                  Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
                  Files_Suite.Support.Assert_Equal
                    (Step.Status,
                     Files.Operations.Operation_Failed,
                     "partial Redo retains completed A and the pending action across repeated failures: status");
                  Assert
                    (File_Has_Bytes (Dest_A, "original a"),
                     "partial Redo retains completed A and the pending action across repeated failures: A kept");
                  Assert
                    (Files.Model.Redo_Available (Model),
                     "partial Redo retains completed A and the pending action across repeated failures"
                     & ": redo available");
                  Assert
                    (not Files.Model.Undo_Available (Model),
                     "partial Redo retains completed A and the pending action across repeated failures"
                     & ": undo unavailable");
                  if not Missing_Source then
                     Assert (File_Has_Bytes (Dest_B, "unrelated collision"),
                             "a pending Redo never claims or overwrites an unrelated destination");
                  end if;
               end loop;
               Ada.Directories.Delete_File (Dest_A);
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Failed,
                  "a partial Redo recreates an output missing behind its completion marker: status");
               Assert
                 (File_Has_Bytes (Dest_A, "original a"),
                  "a partial Redo recreates an output missing behind its completion marker: A recreated");
               Assert
                 (Files.Model.Redo_Available (Model),
                  "a partial Redo recreates an output missing behind its completion marker: redo available");
               Assert
                 (Hostkit.Fs.Move_No_Replace (Dest_A, Saved_A),
                  "move the completed output aside without following links");
               if Kind = Files.Model.Create_Symbolic_Link then
                  Assert
                    (Hostkit.Fs.Is_Link (Saved_A),
                     "moving a completed symbolic link preserves the link");
               end if;
               Write_Binary_File (Dest_A, "unrelated replacement");
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Failed,
                  "a stale completion marker does not claim or overwrite a replacement: status");
               Assert
                 (File_Has_Bytes (Dest_A, "unrelated replacement"),
                  "a stale completion marker does not claim or overwrite a replacement: replacement kept");
               Assert
                 (Files.Model.Redo_Available (Model),
                  "a stale completion marker does not claim or overwrite a replacement: redo available");
               Ada.Directories.Delete_File (Dest_A);
               Assert
                 (Hostkit.Fs.Move_No_Replace (Saved_A, Dest_A),
                  "restore the completed output without following links");
               if Kind = Files.Model.Create_Symbolic_Link then
                  Assert
                    (Hostkit.Fs.Is_Link (Dest_A),
                     "restoring a completed symbolic link preserves the link");
               end if;
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Failed,
                  "restoring the verified output makes the invalidated marker retryable: status");
               Assert
                 (File_Has_Bytes (Dest_A, "original a"),
                  "restoring the verified output makes the invalidated marker retryable: A kept");
               Assert
                 (Files.Model.Redo_Available (Model),
                  "restoring the verified output makes the invalidated marker retryable: redo available");
               if Missing_Source then
                  Ada.Directories.Rename (Held_B, Source_B);
               else
                  Ada.Directories.Delete_File (Dest_B);
               end if;
               --  Completed A no longer needs its source to finish B.
               Ada.Directories.Rename (Source_A, Held_A);
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "unblocking B completes Redo despite A's now-missing source and returns it to Undo history: "
                  & Files.Model.Undo_Create_Kind'Image (Kind)
                  & " missing=" & Boolean'Image (Missing_Source)
                  & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                  & " redo=" & Boolean'Image (Files.Model.Redo_Available (Model))
                  & " undo=" & Boolean'Image (Files.Model.Undo_Available (Model))
                  & " b=" & Boolean'Image (File_Has_Bytes (Dest_B, "original b")) & ": status");
               Assert
                 (not Files.Model.Redo_Available (Model),
                  "unblocking B completes Redo despite A's now-missing source and returns it to Undo history: "
                  & Files.Model.Undo_Create_Kind'Image (Kind)
                  & " missing=" & Boolean'Image (Missing_Source)
                  & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                  & " redo=" & Boolean'Image (Files.Model.Redo_Available (Model))
                  & " undo=" & Boolean'Image (Files.Model.Undo_Available (Model))
                  & " b=" & Boolean'Image (File_Has_Bytes (Dest_B, "original b")) & ": redo consumed");
               Assert
                 (Files.Model.Undo_Available (Model),
                  "unblocking B completes Redo despite A's now-missing source and returns it to Undo history: "
                  & Files.Model.Undo_Create_Kind'Image (Kind)
                  & " missing=" & Boolean'Image (Missing_Source)
                  & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                  & " redo=" & Boolean'Image (Files.Model.Redo_Available (Model))
                  & " undo=" & Boolean'Image (Files.Model.Undo_Available (Model))
                  & " b=" & Boolean'Image (File_Has_Bytes (Dest_B, "original b")) & ": undo available");
               Assert
                 (File_Has_Bytes (Dest_B, "original b"),
                  "unblocking B completes Redo despite A's now-missing source and returns it to Undo history: "
                  & Files.Model.Undo_Create_Kind'Image (Kind)
                  & " missing=" & Boolean'Image (Missing_Source)
                  & " status=" & Files.Operations.Operation_Status'Image (Step.Status)
                  & " redo=" & Boolean'Image (Files.Model.Redo_Available (Model))
                  & " undo=" & Boolean'Image (Files.Model.Undo_Available (Model))
                  & " b=" & Boolean'Image (File_Has_Bytes (Dest_B, "original b")) & ": B created");
               Ada.Directories.Rename (Held_A, Source_A);
               Assert (File_Has_Bytes (Dest_A, "original a"), "completed A retains its original bytes");
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "Undo reverses the entire recovered action: status");
               Assert
                 (not Ada.Directories.Exists (Dest_A) and then not Hostkit.Fs.Is_Link (Dest_A),
                  "Undo reverses the entire recovered action: A removed");
               Assert
                 (not Ada.Directories.Exists (Dest_B) and then not Hostkit.Fs.Is_Link (Dest_B),
                  "Undo reverses the entire recovered action: B removed");
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "a new Redo cycle re-creates both items instead of reusing stale progress: status");
               Assert
                 (File_Has_Bytes (Dest_A, "original a"),
                  "a new Redo cycle re-creates both items instead of reusing stale progress: A created");
               Assert
                 (File_Has_Bytes (Dest_B, "original b"),
                  "a new Redo cycle re-creates both items instead of reusing stale progress: B created");
               Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "the second full Redo also records a usable Undo action");
            end;
         end loop;
      end loop;
   end Test_Partial_Redo_Creation;
