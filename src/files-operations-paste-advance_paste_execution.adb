with Files.Model.Jobs;
with Files.File_System_Types;
with Files.File_System.Transfer;

separate (Files.Operations.Paste)
function Advance_Paste_Execution
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Max_Items : Positive)
   return Operation_Result
is
   Processed : Natural := 0;

   --  A failed move that still published its copy left its source in place
   --  (its removal was refused, and so was removing the copy) unless the
   --  source went to a recovery stage. Only a vacated source makes the copy
   --  a move; otherwise undo must delete the copy, not move it back.
   function Source_Remains (Action : Files.Paste.Resolved_Action) return Boolean is
     (Files.Model.Pasting.Execution_Mode (Model) = Files.File_System_Types.Drop_Move
      --  refusal-safe: a refused source counts as vacated, so undo moves the copy back
      --  without replacing anything and never deletes what may be the only copy
      and then Files.IO.Fs_Primitives.Entry_Exists (To_String (Action.Source_Path)));

   --  Start the current action in a helper when none runs, then poll it:
   --  the model holds the transfer handle, this drives it.
   procedure Advance_Background_Paste
     (Model    : in out Files.Model.Window_Model;
      Finished : out Boolean;
      Result   : out Files.Transfer_Jobs.Job_Result)
   is
      Job : Files.Transfer_Jobs.Session := Files.Model.Pasting.Job (Model);
   begin
      if not Files.Transfer_Jobs.Active (Job) then
         if Files.Model.Pasting.Execution_Cancelled (Model) then
            Finished := True;
            Result := (Cancelled => True, others => <>);
            return;
         end if;
         begin
            Files.Transfer_Jobs.Start
              (Job,
               Files.Model.Pasting.Execution_Action (Model, Files.Model.Pasting.Execution_Cursor (Model) + 1),
               Files.Model.Pasting.Execution_Mode (Model), Files.Model.Pasting.Execution_Copy_Context (Model));
         exception
            when Failure : others =>
               --  No helper (a process limit, a full temporary volume): the
               --  paste ends here with the error, its finished part kept for
               --  undo. Raising instead left it armed, and every loop pass
               --  raised again before the window could repaint.
               Files.Diagnostics.Note (Failure, "Files.Operations");
               Finished := True;
               Result :=
                 (Mutation => (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed")),
                  others   => <>);
               return;
         end;
         Files.Model.Pasting.Set_Job (Model, Job);
         Files.Model.Pasting.Note_Action_Started (Model);
      end if;
      Files.Transfer_Jobs.Poll (Job, Finished, Result);
      if Finished then
         Files.Transfer_Jobs.Reset (Job);
         Files.Model.Pasting.Set_Job (Model, Job);
      end if;
   end Advance_Background_Paste;

   --  Settle one finished action, whichever ran it (a helper, or this
   --  window when there are no background transfers): the original it
   --  replaced recorded for undo, its copy recorded -- or kept aside, when
   --  a failed move left its source -- and the paste finalized when the
   --  action failed, was cancelled or recovered, or the paste was cancelled.
   --
   --  @param Action The action that ran.
   --  @param Result What it did.
   --  @param Ended True when the paste is over; Outcome is then its result.
   --  @param Outcome The finalized paste's result when Ended.
   procedure Settle_Action
     (Action  : Files.Paste.Resolved_Action;
      Result  : Files.Transfer_Jobs.Job_Result;
      Ended   : out Boolean;
      Outcome : out Operation_Result) is separate;

begin
   if not Files.Model.Pasting.Execution_Is_Active (Model) then
      return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
   end if;

   while Processed < Max_Items
     and then (not Files.Model.Pasting.Execution_Cancelled (Model)
               or else Files.Model.Jobs.Background_Transfers (Model))
     and then Files.Model.Pasting.Execution_Cursor (Model)
              < Files.Model.Pasting.Execution_Action_Count (Model)
   loop
      declare
         Index  : constant Positive := Files.Model.Pasting.Execution_Cursor (Model) + 1;
         Action : constant Files.Paste.Resolved_Action :=
           Files.Model.Pasting.Execution_Action (Model, Index);
      begin
         if Action.Skip then
            Files.Model.Pasting.Skip_Action (Model);
         else
            declare
               Finished : Boolean := True;
               Result   : Files.Transfer_Jobs.Job_Result;
               Ended    : Boolean;
               Outcome  : Operation_Result;
            begin
               if Files.Model.Jobs.Background_Transfers (Model) then
                  Advance_Background_Paste (Model, Finished, Result);
                  if not Finished then
                     return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
                  end if;
               else
                  Result.Mutation :=
                    Files.File_System.Transfer.Import_Replacing
                      (Source                => To_String (Action.Source_Path),
                       Destination           => To_String (Action.Dest_Path),
                       Mode                  => Files.Model.Pasting.Execution_Mode (Model),
                       Replace               => Action.Replaced,
                       Replaced              => Result.Trashed,
                       Replaced_Identity     => Result.Trashed_Identity,
                       Created_Identity      => Result.Created_Identity,
                       Created_Tree_Revision => Result.Created_Tree_Revision,
                       Batch                 => Files.Model.Pasting.Execution_Copy_Context (Model));
               end if;
               Settle_Action (Action, Result, Ended, Outcome);
               if Ended then
                  return Outcome;
               end if;
            end;
         end if;
      end;
      Processed := Processed + 1;
   end loop;

   if Files.Model.Pasting.Execution_Cancelled (Model)
     or else Files.Model.Pasting.Execution_Cursor (Model)
             >= Files.Model.Pasting.Execution_Action_Count (Model)
   then
      return Finalize_Paste_Execution (Model, Settings, "");
   end if;

   return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
end Advance_Paste_Execution;
