separate (Files.Operations)
function Replay
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Direction : Replay_Direction)
   return Operation_Result
is
   Redo      : constant Boolean := Direction = Replay_Redo;
   Directory : constant String := Files.Model.Current_Path (Model);
   Action    : Files.Model.Undo_Entry;
   Found     : Boolean := False;
   Returned_Action : Boolean := False;
   Succeeded : Boolean;

   --  Push Action onto the redo stack (To_Redo) or the undo stack.
   procedure Push (To_Redo : Boolean) is
   begin
      if To_Redo then
         Files.Model.History.Push_Redo (Model, Action);
      else
         Files.Model.History.Push_Undo (Model, Action);
      end if;
      Settle_History (Model);
   end Push;

   --  What a fully applied entry forgets before it moves to the other stack.
   --  A redone action starts a fresh undo cycle; an undone one starts a
   --  fresh redo cycle for the full action, every step of both to do again.
   procedure Clear_Completed_Steps is
   begin
      Action.Forward_Completed.Clear;
      if not Redo then
         Action.Reverse_Completed.Clear;
         Action.Restores_Completed.Clear;
         Action.Copy_Records.Clear;
      end if;
   end Clear_Completed_Steps;
begin
   --  A helper replays only what its journal hands it: an entry too large
   --  for the journal is replayed here instead.
   if Files.Model.Background_Transfers (Model)
     and then Files.History_Journal.Journals_Newest (Model, Redo => Redo)
   then
      return Files.Operation_Jobs.Start
        (Model, Settings, (if Redo then Files.Operation_Jobs.Redo else Files.Operation_Jobs.Undo));
   end if;
   if Redo then
      Files.Model.History.Take_Redo (Model, Action, Found);
   else
      Files.Model.History.Take_Undo (Model, Action, Found);
   end if;
   if not Found then
      Files.Model.Set_Error (Model, "error.undo.failed");
      return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end if;

   Files.History_Journal.Checkpoint (Model, Action, Redo);
   if Redo then
      Succeeded := Apply_Forward (Action, Model);
   else
      Succeeded := Apply_Reverse (Action, Model);
   end if;

   --  A partly applied entry goes back onto the stack it came from instead
   --  of vanishing from history, its completed steps retained so a retry
   --  only applies unfinished work, preserving restored originals (mode and
   --  owner restores are idempotent). A fully applied one moves to the
   --  other stack, without disturbing the rest of that history; an
   --  undo-only action that fully succeeded is simply consumed.
   if not Succeeded then
      Push (To_Redo => Redo);
   elsif Redo or else Action.Redoable then
      Clear_Completed_Steps;
      Push (To_Redo => not Redo);
   end if;

   Returned_Action := True;
   return Finish_Action (Model, Settings, Directory, Succeeded);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      if Found and then not Returned_Action then
         Push (To_Redo => Redo);
      end if;
      Files.Model.Set_Error (Model, "error.undo.failed");
      return Make_Result (Operation_Failed, "error.undo.failed", Directory);
end Replay;
