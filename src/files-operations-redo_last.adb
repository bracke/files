separate (Files.Operations)
   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Directory : constant String := Files.Model.Current_Path (Model);
      Action    : Files.Model.Undo_Entry;
      Found     : Boolean;
      Succeeded : Boolean;
   begin
      Files.Model.Take_Redo (Model, Action, Found);
      if not Found then
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Succeeded := Apply_Forward (Action);

      --  A fully re-applied action returns to the undo stack without disturbing
      --  the rest of the redo history. If it only partially applied, it goes
      --  back onto the redo stack rather than being dropped, so the redo stays
      --  available for a retry (Apply_Forward's Exists_Safely guards keep a
      --  retry from overwriting the items that already re-applied).
      if Succeeded then
         Files.Model.Push_Undo (Model, Action);
      else
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
   end Redo_Last;
