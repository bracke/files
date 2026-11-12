separate (Files.Operations)
function Advance_Paste_Execution
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Max_Items : Positive)
   return Operation_Result
is
   Processed : Natural := 0;
   --  Start the current action in a helper when none runs, then poll it:
   --  the model holds the transfer handle, this drives it.
   procedure Advance_Background_Paste
     (Model    : in out Files.Model.Window_Model;
      Finished : out Boolean;
      Result   : out Files.Transfer_Jobs.Job_Result)
   is
      Job : Files.Transfer_Jobs.Session := Files.Model.Paste_Job (Model);
   begin
      if not Files.Transfer_Jobs.Active (Job) then
         if Files.Model.Paste_Execution_Cancelled (Model) then
            Finished := True;
            Result := (Cancelled => True, others => <>);
            return;
         end if;
         begin
            Files.Transfer_Jobs.Start
              (Job,
               Files.Model.Paste_Execution_Action (Model, Files.Model.Paste_Execution_Cursor (Model) + 1),
               Files.Model.Paste_Execution_Mode (Model), Files.Model.Paste_Execution_Copy_Context (Model));
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
         Files.Model.Set_Paste_Job (Model, Job);
         Files.Model.Note_Paste_Action_Started (Model);
      end if;
      Files.Transfer_Jobs.Poll (Job, Finished, Result);
      if Finished then
         Files.Transfer_Jobs.Reset (Job);
         Files.Model.Set_Paste_Job (Model, Job);
      end if;
   end Advance_Background_Paste;

begin
   if Files.Process_Jobs.Active (Files.Model.Background_Operation (Model)) then
      return Files.Operation_Jobs.Advance (Model, Settings);
   end if;
   if not Files.Model.Paste_Execution_Is_Active (Model) then
      return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
   end if;

   while Processed < Max_Items
     and then (not Files.Model.Paste_Execution_Cancelled (Model)
               or else Files.Model.Background_Transfers (Model))
     and then Files.Model.Paste_Execution_Cursor (Model)
              < Files.Model.Paste_Execution_Action_Count (Model)
   loop
      declare
         Index  : constant Positive := Files.Model.Paste_Execution_Cursor (Model) + 1;
         Action : constant Files.Paste.Resolved_Action :=
           Files.Model.Paste_Execution_Action (Model, Index);
      begin
         if Action.Skip then
            Files.Model.Skip_Paste_Execution_Action (Model);
         elsif Files.Model.Background_Transfers (Model) then
            declare
               Finished : Boolean;
               Result   : Files.Transfer_Jobs.Job_Result;
            begin
               Advance_Background_Paste (Model, Finished, Result);
               if not Finished then
                  return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
               end if;
               if Length (Result.Trashed) > 0 then
                  Record_Paste_Replaced_Trash
                    (Model, Result.Trashed, To_String (Result.Trashed_Identity), To_String (Action.Dest_Path));
               end if;
               if Result.Cancelled then
                  return Finalize_Paste_Execution (Model, Settings, "");
               elsif not Result.Mutation.Success then
                  return Finalize_Paste_Execution (Model, Settings, To_String (Result.Mutation.Error_Key));
               end if;
               Record_Paste_Write
                 (Model, Action.Dest_Path, Action.Source_Path,
                  Files.Fs_Primitives.Leaf_Text (To_String (Action.Dest_Path)),
                  To_String (Result.Created_Identity), To_String (Result.Created_Tree_Revision),
                  Retain_Verified_Snapshot => Result.Recovered);
               if Result.Recovered then
                  return Finalize_Paste_Execution (Model, Settings, "error.drop.failed");
               end if;
               if Files.Model.Paste_Execution_Cancelled (Model) then
                  return Finalize_Paste_Execution (Model, Settings, "");
               end if;
            end;
         else
            declare
               Replaced_Trash, Replaced_Identity : Files.Types.UString;
               Created_Identity, Created_Tree_Revision : Files.Types.UString;
               Mutation : constant Files.File_System.Mutation_Result :=
                 Files.File_System.Import_Replacing
                   (Source                => To_String (Action.Source_Path),
                    Destination           => To_String (Action.Dest_Path),
                    Mode                  => Files.Model.Paste_Execution_Mode (Model),
                    Replace               => Action.Replaced,
                    Replaced              => Replaced_Trash,
                    Replaced_Identity     => Replaced_Identity,
                    Created_Identity      => Created_Identity,
                    Created_Tree_Revision => Created_Tree_Revision,
                    Batch                 => Files.Model.Paste_Execution_Copy_Context (Model));
            begin
               --  An original still held after the action (the write
               --  succeeded, or neither it nor putting it back did) is
               --  tracked so the paste's undo entry can restore it.
               if Length (Replaced_Trash) > 0 then
                  Record_Paste_Replaced_Trash
                    (Model, Replaced_Trash, To_String (Replaced_Identity), To_String (Action.Dest_Path));
               end if;
               if not Mutation.Success then
                  return Finalize_Paste_Execution (Model, Settings, To_String (Mutation.Error_Key));
               end if;
               Record_Paste_Write
                 (Model,
                  Action.Dest_Path,
                  Action.Source_Path,
                  Files.Fs_Primitives.Leaf_Text (To_String (Action.Dest_Path)),
                  To_String (Created_Identity),
                  To_String (Created_Tree_Revision));
            end;
         end if;
      end;
      Processed := Processed + 1;
   end loop;

   if Files.Model.Paste_Execution_Cancelled (Model)
     or else Files.Model.Paste_Execution_Cursor (Model)
             >= Files.Model.Paste_Execution_Action_Count (Model)
   then
      return Finalize_Paste_Execution (Model, Settings, "");
   end if;

   return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
end Advance_Paste_Execution;
