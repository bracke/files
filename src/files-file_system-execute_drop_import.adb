separate (Files.File_System)
function Execute_Drop_Import
  (Plans   : Drop_Import_Plan_Vectors.Vector;
   Created : out Created_Entry_Vectors.Vector;
   Cancel  : Cancellation_Check := Job_Cancelled;
   Batch   : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
   return Mutation_Result
is
   Context : Files.Copy_Context.Session := Batch;
begin
   Created.Clear;
   if Natural (Plans.Length) > 1 and then Files.Copy_Context.Directory (Context) = "" then
      Context := Files.Copy_Context.Create;
   end if;
   for Plan of Plans loop
      if not Plan.Valid then
         return
           (Success   => False,
            Error_Key =>
              (if Length (Plan.Error_Key) > 0
               then Plan.Error_Key
               else To_Unbounded_String ("error.drop.failed")));
      end if;
   end loop;

   for Plan of Plans loop
      declare
         Source_Path      : constant String := To_String (Plan.Source_Path);
         Destination_Path : constant String := To_String (Plan.Destination_Path);
         Published_Identity, Published_Tree_Revision : UString;

      begin
         Files.Io_Errors.Reset;
         if Source_Path = Destination_Path and then Plan.Mode = Drop_Copy then
            return (Success => False, Error_Key => To_Unbounded_String ("error.drop.into_self"));
         end if;
         --  A destination may have appeared since planning. It belongs to
         --  someone else and must never be removed by failure cleanup; one
         --  the host will not answer for may be such an entry too.
         if Source_Path /= Destination_Path
           and then not Files.Fs_Primitives.Entry_Is_Absent (Destination_Path)
         then
            return (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
         end if;
         if Cancel /= null and then Cancel.all then
            return (Success => False, Error_Key => To_Unbounded_String (Cancelled_Error_Key));
         end if;
         if Plan.Mode = Drop_Move then
            if Source_Path /= Destination_Path then
               declare
                  use type Hostkit.Fs.Move_Outcome;
                  Identity : constant String := Files.File_Identities.Token (Source_Path);
                  Outcome  : Hostkit.Fs.Move_Outcome := Hostkit.Fs.Move_Refused;
               begin
                  if Identity /= "" then
                     --  Named before it moves, so a helper stopped right
                     --  after still has it found (Files.Job_Context.Read_Moved).
                     Files.Job_Context.Intend_Moved (Destination_Path, Source_Path, Identity);
                     Outcome := Support.Move_No_Replace_Outcome (Source_Path, Destination_Path);
                  end if;
                  if Identity = ""
                    or else (Outcome /= Hostkit.Fs.Moved and then not Support.Copy_May_Replace_Move (Outcome))
                  then
                     --  A rename the filesystem refused for any reason but a
                     --  device boundary (permission, a busy or vanished source,
                     --  a target that appeared) would refuse a copy and delete
                     --  too, or do what the rename would not.
                     return
                       (Success   => False,
                        Error_Key => Files.Io_Errors.Error_Key ("error.drop.failed"));
                  elsif Outcome = Hostkit.Fs.Moved then
                     --  The move is committed. Only a cross-device rename may
                     --  use the copy/delete fallback. A rename needs no content
                     --  snapshot: move recovery and Undo use the entry identity.
                     Published_Identity := To_Unbounded_String (Identity);
                     Published_Tree_Revision := Null_Unbounded_String;
                     Files.Job_Context.Record_Moved (Destination_Path, Source_Path, Identity);
                  else
                     declare
                        Copied_Identity, Copied_Tree_Revision : UString;
                        Copy_Kept : Boolean;
                        Moved : constant Mutation_Result :=
                          Recovery.Move_By_Copy
                            (Source_Path, Destination_Path, "error.drop.failed",
                             Copied_Identity, Copied_Tree_Revision, Copy_Kept, Cancel, Context);
                     begin
                        if not Moved.Success then
                           if Copy_Kept then
                              --  The copy had to stay: the source was set
                              --  aside in recovery (the move is in effect
                              --  done), or the copy could not be removed.
                              --  It is the plan's result either way; return
                              --  it so undo covers it. Copy_To_New_Path
                              --  recorded it as created; a vacated source
                              --  makes it a move.
                              if Files.Fs_Primitives.Entry_Is_Absent (Source_Path) then
                                 Files.Job_Context.Record_Moved
                                   (Destination_Path, Source_Path, To_String (Copied_Identity));
                              end if;
                              Created.Append
                                (Created_Entry'(Identity => Copied_Identity, Tree_Revision => Copied_Tree_Revision));
                           end if;
                           --  Otherwise nothing is at the destination and the
                           --  source stays canonical, so paste-replace can
                           --  restore its original destination. A copy the
                           --  cancel stopped says so -- but only a failure
                           --  with no cause of its own: a kept copy (a source
                           --  set aside) or a full disk is reported as such.
                           declare
                              Cancelled : constant Boolean := Cancel /= null and then Cancel.all;
                           begin
                              if Cancelled and then not Copy_Kept
                                and then Says_Only_Stopped (To_String (Moved.Error_Key), Copy_Step)
                              then
                                 return (Success => False, Error_Key => To_Unbounded_String (Cancelled_Error_Key));
                              end if;
                           end;
                           return Moved;
                        end if;
                        Files.Job_Context.Record_Moved
                          (Destination_Path, Source_Path, To_String (Copied_Identity));
                        Published_Identity := Copied_Identity;
                        Published_Tree_Revision := Copied_Tree_Revision;
                     end;
                  end if;
               end;
            else
               Published_Identity := To_Unbounded_String (Files.File_Identities.Token (Destination_Path));
               Published_Tree_Revision := To_Unbounded_String (Tree_Revision (Destination_Path));
            end if;
         else
            Support.Copy_To_New_Path
              (Source_Path, Destination_Path, Published_Identity, Published_Tree_Revision,
               Cancel => Cancel, Batch => Context);
         end if;
         Created.Append (Created_Entry'(Identity => Published_Identity, Tree_Revision => Published_Tree_Revision));
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
            --  A copy raised partway (e.g. out of space). Copy_To_New_Path
            --  removes its own private stage when it raises, and nothing it
            --  does after publishing raises, so no partial destination is
            --  left and nothing is cleaned up here; the source is untouched.
            --  A cancelled copy says so (the helper reads it as cancelled),
            --  unless the failure has a cause of its own, a full disk say.
            declare
               Cancelled : constant Boolean := Cancel /= null and then Cancel.all;
               Key       : constant UString := Files.Io_Errors.Error_Key ("error.drop.failed");
            begin
               return
                 (Success   => False,
                  Error_Key =>
                    (if Cancelled and then Says_Only_Stopped (To_String (Key), Copy_Step)
                     then To_Unbounded_String (Cancelled_Error_Key)
                     else Key));
            end;
      end;
   end loop;

   return (Success => True, Error_Key => Null_Unbounded_String);
end Execute_Drop_Import;
