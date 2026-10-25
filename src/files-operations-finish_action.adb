separate (Files.Operations)
function Finish_Action
  (Model : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model;
   Directory : String;
   Succeeded : Boolean) return Operation_Result
is
   Error_Key : constant String := (if Succeeded then "" else "error.undo.failed");
begin
   --  Finalize visible state before a helper captures the model revision.
   --  Updating the error after launch would invalidate this action's reload.
   Files.Model.Set_Error (Model, Error_Key);
   declare
      Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      pragma Unreferenced (Reload);
   begin
      null;
   end;
   if not Files.Model.Background_Transfers (Model) then
      --  Synchronous reloads can clear or replace the error; retain the
      --  history action's final status for headless callers as before.
      Files.Model.Set_Error (Model, Error_Key);
   end if;
   return Make_Result
     ((if Succeeded then Operation_Success else Operation_Failed), Error_Key, Directory);
end Finish_Action;
