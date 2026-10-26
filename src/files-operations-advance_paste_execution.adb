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
         Files.Transfer_Jobs.Start
           (Job,
            Files.Model.Paste_Execution_Action (Model, Files.Model.Paste_Execution_Cursor (Model) + 1),
            Files.Model.Paste_Execution_Mode (Model), Files.Model.Paste_Execution_Copy_Context (Model));
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
                  Ada.Directories.Simple_Name (To_String (Action.Dest_Path)),
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
               Replaced_Trash, Replaced_Identity : Files.Types.UString := Null_Unbounded_String;
               Created_Identities, Created_Tree_Revisions : Files.Types.String_Vectors.Vector;
               function Preserve_Replacement return Boolean is
                  Cleared : constant Boolean := Clear_Replaced_Destination
                    (To_String (Action.Dest_Path), To_String (Action.Source_Path), Replaced_Trash);
               begin
                  if Length (Replaced_Trash) > 0 then
                     Replaced_Identity := To_Unbounded_String
                       (Files.File_Identities.Token (To_String (Replaced_Trash)));
                  end if;
                  return Cleared;
               end Preserve_Replacement;
            begin
               if Action.Replaced and then not Preserve_Replacement
               then
                  if Length (Replaced_Trash) > 0 then
                     Record_Paste_Replaced_Trash
                       (Model, Replaced_Trash, To_String (Replaced_Identity), To_String (Action.Dest_Path));
                  end if;
                  return Finalize_Paste_Execution (Model, Settings, "error.drop.failed");
               end if;

               declare
                  Plans : Files.File_System.Drop_Import_Plan_Vectors.Vector;
               begin
                  Plans.Append
                    (Files.File_System.Drop_Import_Plan'
                       (Source_Path      => Action.Source_Path,
                        Destination_Path => Action.Dest_Path,
                        Mode             => Files.Model.Paste_Execution_Mode (Model),
                        Valid            => True,
                        Error_Key        => Null_Unbounded_String));
                  declare
                     Mutation : constant Files.File_System.Mutation_Result :=
                       Files.File_System.Execute_Drop_Import
                         (Plans, Created_Identities, Created_Tree_Revisions,
                          Batch => Files.Model.Paste_Execution_Copy_Context (Model));
                  begin
                     if not Mutation.Success then
                        --  The destination was just cleared but the write
                        --  failed: put the trashed original back so a mid-paste
                        --  failure never loses the pre-existing file.
                        if Length (Replaced_Trash) > 0 then
                           declare
                              Restored : constant Files.File_System.Mutation_Result :=
                                Files.File_System.Restore_From_Trash
                                  (To_String (Replaced_Trash), To_String (Replaced_Identity),
                                   To_String (Action.Dest_Path));
                           begin
                              if not Restored.Success then
                                 Record_Paste_Replaced_Trash
                       (Model, Replaced_Trash, To_String (Replaced_Identity), To_String (Action.Dest_Path));
                                 return Finalize_Paste_Execution
                                   (Model, Settings, To_String (Restored.Error_Key));
                              end if;
                           end;
                        end if;
                        return Finalize_Paste_Execution
                          (Model, Settings, To_String (Mutation.Error_Key));
                     end if;
                  end;
               end;

               --  Write succeeded: track the overwritten original's trash
               --  location so the paste's undo entry can restore it.
               if Length (Replaced_Trash) > 0 then
                  Record_Paste_Replaced_Trash
                       (Model, Replaced_Trash, To_String (Replaced_Identity), To_String (Action.Dest_Path));
               end if;

               Record_Paste_Write
                 (Model,
                  Action.Dest_Path,
                  Action.Source_Path,
                  Ada.Directories.Simple_Name (To_String (Action.Dest_Path)),
                  To_String (Created_Identities.First_Element),
                  To_String (Created_Tree_Revisions.First_Element));
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
