separate (Files.File_System)
function Execute_Drop_Import
  (Plans   : Drop_Import_Plan_Vectors.Vector;
   Created : out Created_Entry_Vectors.Vector;
   Cancel  : Cancellation_Check := Job_Cancelled;
   Batch   : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
   return Mutation_Result
is
   Context : Files.Jobs.Copy_Context.Session := Batch;

   --  The stopped-by-cancel reading of a failed copy: a failure with no
   --  cause of its own (not a full disk, say) is reported as cancelled
   --  once the job is cancelled.
   function Cancelled_Or (Failed : Mutation_Result) return Mutation_Result is
     (if Cancel /= null and then Cancel.all
        and then Says_Only_Stopped (To_String (Failed.Error_Key), Copy_Step)
      then (Success => False, Error_Key => To_Unbounded_String (Cancelled_Error_Key))
      else Failed);

   --  Move one planned entry to its new, different path: named in the
   --  journal before it moves, so a helper stopped right after still has it
   --  found (Files.Jobs.Context.Read_Moved), and recorded as moved after.
   --  @param Source_Path Entry to move.
   --  @param Destination_Path Its new path.
   --  @param Published_Identity The identity of what is at Destination_Path.
   --  @param Published_Tree_Revision Its tree revision; empty after a rename.
   --  @return Success when the entry moved; on failure, Created may still
   --    hold a copy that had to stay.
   function Move_Entry
     (Source_Path, Destination_Path                : String;
      Published_Identity, Published_Tree_Revision : out UString)
      return Mutation_Result
   is
      use type Recovery.Move_Route;
      Identity : constant String := Files.File_Identities.Token (Source_Path);
   begin
      Published_Identity := Null_Unbounded_String;
      Published_Tree_Revision := Null_Unbounded_String;
      if Identity = "" then
         return (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.drop.failed"));
      end if;
      Files.Jobs.Context.Intend_Moved (Destination_Path, Source_Path, Identity);
      declare
         Route : Recovery.Move_Route;
         Copied_Identity, Copied_Tree_Revision : UString;
         Copy_Kept : Boolean;
         --  A rename the filesystem refused for any reason but a device
         --  boundary (permission, a busy or vanished source, a target that
         --  appeared) would refuse a copy and delete too, or do what the
         --  rename would not: it fails with no copy. Only a cross-device
         --  rename uses the copy/delete fallback.
         Moved : constant Mutation_Result :=
           Recovery.Move_Or_Copy
             (Source_Path, Destination_Path, "error.drop.failed",
              Route, Copied_Identity, Copied_Tree_Revision, Copy_Kept, Cancel, Context);
      begin
         if Route = Recovery.Renamed then
            --  The move is committed. A rename needs no content snapshot:
            --  move recovery and Undo use the entry identity.
            Published_Identity := To_Unbounded_String (Identity);
            Files.Jobs.Context.Record_Moved (Destination_Path, Source_Path, Identity);
            return Moved;
         elsif Moved.Success then
            Files.Jobs.Context.Record_Moved (Destination_Path, Source_Path, To_String (Copied_Identity));
            Published_Identity := Copied_Identity;
            Published_Tree_Revision := Copied_Tree_Revision;
            return Moved;
         elsif not Copy_Kept then
            --  Nothing is at the destination and the source stays
            --  canonical, so paste-replace can restore its original
            --  destination. A copy the cancel stopped says so.
            return (if Route = Recovery.Copied then Cancelled_Or (Moved) else Moved);
         end if;
         --  The copy had to stay: the source was set aside in recovery (the
         --  move is in effect done), or the copy could not be removed. It is
         --  the plan's result either way; return it so undo covers it.
         --  Copy_To_New_Path recorded it as created; a vacated source makes
         --  it a move. A kept copy is reported with its own cause.
         if Files.Fs_Primitives.Entry_Is_Absent (Source_Path) then
            Files.Jobs.Context.Record_Moved (Destination_Path, Source_Path, To_String (Copied_Identity));
         end if;
         Created.Append (Created_Entry'(Identity => Copied_Identity, Tree_Revision => Copied_Tree_Revision));
         return Moved;
      end;
   end Move_Entry;
begin
   Created.Clear;
   if Natural (Plans.Length) > 1 and then Files.Jobs.Copy_Context.Directory (Context) = "" then
      Context := Files.Jobs.Copy_Context.Create;
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
                  Moved : constant Mutation_Result :=
                    Move_Entry (Source_Path, Destination_Path, Published_Identity, Published_Tree_Revision);
               begin
                  if not Moved.Success then
                     return Moved;
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
            return Cancelled_Or ((Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.drop.failed")));
      end;
   end loop;

   return (Success => True, Error_Key => Null_Unbounded_String);
end Execute_Drop_Import;
