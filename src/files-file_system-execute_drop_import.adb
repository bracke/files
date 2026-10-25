separate (Files.File_System)
function Execute_Drop_Import
  (Plans  : Drop_Import_Plan_Vectors.Vector;
   Created_Identities, Created_Tree_Revisions : out Files.Types.String_Vectors.Vector;
   Cancel : Cancellation_Check := null;
   Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
   return Mutation_Result
is
   Context : Files.Copy_Context.Session := Batch;
begin
   Created_Identities.Clear;
   Created_Tree_Revisions.Clear;
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
         --  someone else and must never be removed by failure cleanup.
         if Source_Path /= Destination_Path
           and then (Ada.Directories.Exists (Destination_Path)
                     or else Hostkit.Fs.Is_Link (Destination_Path))
         then
            return (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
         end if;
         if Cancel /= null and then Cancel.all then
            return (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
         end if;
         if Plan.Mode = Drop_Move then
            if Source_Path /= Destination_Path then
               declare
                  use type Hostkit.Fs.Move_Outcome;
                  Identity : constant String := Files.File_Identities.Token (Source_Path);
                  Outcome  : Hostkit.Fs.Move_Outcome := Hostkit.Fs.Move_Refused;
               begin
                  if Identity /= "" then
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
                           --  The source stays canonical (unless set aside),
                           --  so paste-replace can restore its original
                           --  destination.
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
         Created_Identities.Append (Published_Identity);
         Created_Tree_Revisions.Append (Published_Tree_Revision);
      exception
         when others =>
            --  A copy raised partway (e.g. out of space); remove the partial
            --  destination before reporting failure. The source is untouched.
            --  Copy_Tree cleans up only destinations it created. A cancelled
            --  copy keeps the generic key: the helper reads it as cancelled.
            return
              (Success   => False,
               Error_Key =>
                 (if Cancel /= null and then Cancel.all
                  then To_Unbounded_String ("error.drop.failed")
                  else Files.Io_Errors.Error_Key ("error.drop.failed")));
      end;
   end loop;

   return (Success => True, Error_Key => Null_Unbounded_String);
end Execute_Drop_Import;
