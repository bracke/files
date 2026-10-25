separate (Files.Operations)
function Undo_Last
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Directory : constant String := Files.Model.Current_Path (Model);
   Action    : Files.Model.Undo_Entry;
   Found     : Boolean := False;
   Returned_Action : Boolean := False;
   Succeeded : Boolean;
begin
   if Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Undo);
   end if;
   Files.Model.Take_Undo (Model, Action, Found);
   if not Found then
      Files.Model.Set_Error (Model, "error.undo.failed");
      return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end if;

   Files.History_Journal.Checkpoint (Model, Action, False);
   Succeeded := Apply_Reverse (Action, Model);

   --  A fully reversed, redoable action moves onto the redo stack. If the
   --  reverse only partially applied, the entry goes back onto the undo
   --  stack instead of vanishing from history. Completed steps are retained
   --  so a retry only applies unfinished work, preserving restored originals.
   --  Mode/owner restores are idempotent. An undo-only
   --  action that fully succeeded is simply consumed.
   if not Succeeded then
      Files.Model.Push_Undo (Model, Action);
      Settle_History (Model);
   elsif Action.Redoable then
      --  A subsequent redo starts a new Undo cycle for the full action.
      Action.Reverse_Completed.Clear;
      Action.Restores_Completed.Clear;
      Action.Forward_Completed.Clear;
      Action.Copy_Records.Clear;
      Files.Model.Push_Redo (Model, Action);
      Settle_History (Model);
   end if;

   Returned_Action := True;
   return Finish_Action (Model, Settings, Directory, Succeeded);
exception
   when others =>
      if Found and then not Returned_Action then
         Files.Model.Push_Undo (Model, Action);
         Settle_History (Model);
      end if;
      Files.Model.Set_Error (Model, "error.undo.failed");
      return Make_Result (Operation_Failed, "error.undo.failed", Directory);
end Undo_Last;
