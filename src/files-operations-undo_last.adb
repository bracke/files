separate (Files.Operations)
   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Directory : constant String := Files.Model.Current_Path (Model);
      Action    : Files.Model.Undo_Entry;
      Found     : Boolean;
      Succeeded : Boolean;
   begin
      Files.Model.Take_Undo (Model, Action, Found);
      if not Found then
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Succeeded := Apply_Reverse (Action);

      --  A fully reversed, redoable action moves onto the redo stack. If the
      --  reverse only partially applied, the entry goes back onto the undo
      --  stack instead of vanishing from history: re-running is safe (missing
      --  paths count as already undone and mode/owner restores are idempotent)
      --  and lets the user retry the items that did not revert. An undo-only
      --  action that fully succeeded is simply consumed.
      if not Succeeded then
         Files.Model.Push_Undo (Model, Action);
      elsif Action.Redoable then
         Files.Model.Push_Redo (Model, Action);
      end if;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
         pragma Unreferenced (Reload);
      begin
         null;
      end;

      if not Succeeded then
         Files.Model.Set_Error (Model, "error.undo.failed");
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Directory);
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end Undo_Last;
