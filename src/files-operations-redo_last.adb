separate (Files.Operations)
function Redo_Last
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
   --  A helper undoes only what its journal hands it: an entry too large
   --  for the journal is redone here instead.
   if Files.Model.Background_Transfers (Model)
     and then Files.History_Journal.Journals_Newest (Model, Redo => True)
   then
      return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Redo);
   end if;
   Files.Model.History.Take_Redo (Model, Action, Found);
   if not Found then
      Files.Model.Set_Error (Model, "error.undo.failed");
      return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end if;

   Files.History_Journal.Checkpoint (Model, Action, True);
   Succeeded := Apply_Forward (Action, Model);

   --  A fully re-applied action returns to the undo stack without disturbing
   --  the rest of the redo history. If it only partially applied, it goes
   --  back onto the redo stack with its completed steps, so retries only
   --  apply unfinished items. A full Redo starts a fresh Undo/Redo cycle.
   if Succeeded then
      Action.Forward_Completed.Clear;
      Files.Model.History.Push_Undo (Model, Action);
      Settle_History (Model);
   else
      Files.Model.History.Push_Redo (Model, Action);
      Settle_History (Model);
   end if;

   Returned_Action := True;
   return Finish_Action (Model, Settings, Directory, Succeeded);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      if Found and then not Returned_Action then
         Files.Model.History.Push_Redo (Model, Action);
         Settle_History (Model);
      end if;
      Files.Model.Set_Error (Model, "error.undo.failed");
      return Make_Result (Operation_Failed, "error.undo.failed", Directory);
end Redo_Last;
