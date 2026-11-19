separate (Files.Operations)
function Replay
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Direction : Replay_Direction)
   return Operation_Result
is
   Side      : constant Files.Undo_History.History_Side :=
     (if Direction = Replay_Redo then Files.Undo_History.Redo_Side else Files.Undo_History.Undo_Side);
   Redo      : constant Boolean := Direction = Replay_Redo;
   Other     : constant array (Files.Undo_History.History_Side) of Files.Undo_History.History_Side :=
     [Files.Undo_History.Undo_Side => Files.Undo_History.Redo_Side,
      Files.Undo_History.Redo_Side => Files.Undo_History.Undo_Side];
   Directory : constant String := Files.Model.Current_Path (Model);
   Action    : Files.Undo_History.Undo_Entry;
   Found     : Boolean := False;
   Returned_Action : Boolean := False;
   Succeeded : Boolean;

   --  Push Action onto the stack of side Onto.
   procedure Push (Onto : Files.Undo_History.History_Side) is
      use type Files.Undo_History.History_Side;
   begin
      if Onto = Files.Undo_History.Redo_Side then
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
   if Redo then
      Files.Model.History.Take_Redo (Model, Action, Found);
   else
      Files.Model.History.Take_Undo (Model, Action, Found);
   end if;
   if not Found then
      Files.Model.Set_Error (Model, "error.undo.failed");
      return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end if;

   Files.History_Journal.Checkpoint (Files.Model.History.State (Model), Action, Side);
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
      Push (Onto => Side);
   elsif Redo or else Action.Redoable then
      Clear_Completed_Steps;
      Push (Onto => Other (Side));
   end if;

   Returned_Action := True;
   return Finish_Action (Model, Settings, Directory, Succeeded);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      if Found and then not Returned_Action then
         Push (Onto => Side);
      end if;
      Files.Model.Set_Error (Model, "error.undo.failed");
      return Make_Result (Operation_Failed, "error.undo.failed", Directory);
end Replay;
