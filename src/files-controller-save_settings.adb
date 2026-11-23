with Files.Settings.Drafts;
with Files.Operation_Results;
separate (Files.Controller)
   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Applied : constant Files.Settings.Settings_Parse_Result :=
        Files.Settings.Drafts.Apply_Draft (Settings, Files.Model.Settings_Pane.Draft_Of (Model));
      Final     : Files.Settings.Settings_Model;
      --  Whether Final is now the live settings (with what another process
      --  wrote to the file taken in, they need not equal it).
      Accepted  : Boolean := True;
      Saved     : Files.Settings.Settings_Write_Result;
      Operation : Files.Operation_Results.Operation_Result := Empty_Operation;
   begin
      --  Reached only with the pane open: Status_Of disables Save otherwise.
      if not Applied.Success then
         declare
            Draft : Files.Settings.Settings_Draft := Files.Model.Settings_Pane.Draft_Of (Model);
         begin
            Draft.Valid := False;
            Draft.Error_Key := Applied.Error_Key;
            Files.Overlays.Settings_Form.Set_Draft (Model, Draft);
         end;
         Files.Model.Set_Error (Model, To_String (Applied.Error_Key));
         Operation.Status := Files.Operation_Results.Operation_Failed;
         Operation.Error_Key := Applied.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      --  The same policy as every other settings change (Commit_Settings):
      --  applied for the session and saved, a failed or non-durable save
      --  reported, not undone; a draft the file could not hold is refused and
      --  stays open for editing.
      Final := Applied.Settings;
      --  A held arrow stepping a number (or cycling a choice): each step is
      --  in force for the session (Take_In_Settings, which reads the folder
      --  again only for a step that changes what it lists: the hidden filter
      --  or the type maps), and the file is written once, when the key is
      --  let go (the window layer writes what is in force then,
      --  Persist_Held_Settings). A durable write per repeat held the window.
      --  A step the file could not hold is refused as Commit refuses one,
      --  said in the error line; the pane goes back to the value in force,
      --  so letting go writes the steps that were accepted and the pane
      --  shows what was written.
      if Files.Model.Settings_Pane.Key_Repeat (Model) then
         case Apply_Unsaved (Model, Settings, Final, Take_In_All => True) is
            when Files.Settings.Storage.Commit_Refused =>
               Operation.Status := Files.Operation_Results.Operation_Failed;
               Operation.Error_Key := Files.Settings.Storage.Full_Result (Settings_Path).Error_Key;
               Operation.Path := To_Unbounded_String (Settings_Path);
            when Files.Settings.Storage.Commit_Accepted =>
               Files.Model.Settings_Pane.Defer_Save (Model);
            when Files.Settings.Storage.Commit_Unchanged =>
               null;
         end case;
         Files.Overlays.Settings_Form.Set_Draft
           (Model, Files.Settings.Drafts.Draft_After_Save (Files.Model.Settings_Pane.Draft_Of (Model), Settings));
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;
      --  Save writes even an unchanged draft: it is how a save that failed
      --  earlier is tried again.
      if Files.Settings.Same_Content (Settings, Final) then
         Saved := Persisted (Model, Settings, Settings_Path);
      else
         declare
            Outcome : constant Commit_Outcome := Commit (Model, Settings, Final, Settings_Path);
         begin
            Saved := Outcome.Saved;
            Accepted := Outcome.Accepted;
         end;
      end if;
      if not Accepted then
         Operation.Status := Files.Operation_Results.Operation_Failed;
         Operation.Error_Key := Saved.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      --  Apply the saved view mode and sort to the live model so a change made in
      --  the settings pane takes effect now, not only on the next launch. Do this
      --  before the refresh so the reload lists items in the new order.
      Files.Operations.Apply_Ui_State (Model, Settings);

      Operation := Files.Operations.Refresh (Model, Settings);
      --  The pane shows what was saved -- every mapping row as the file
      --  holds it -- with each mapping editor still on the entry it was on,
      --  and a row just added and not yet filled in kept. Rebuilding the
      --  draft from the saved settings alone would send every group back to
      --  its first entry.
      Files.Overlays.Settings_Form.Set_Draft
        (Model, Files.Settings.Drafts.Draft_After_Save (Files.Model.Settings_Pane.Draft_Of (Model), Settings));
      --  The settings now applied, for the pane's next change. A write that
      --  failed was reported; Save (which always writes) tries it again.
      Files.Overlays.Settings_Form.Mark_Saved (Model, Settings);
      if Operation.Status = Files.Operation_Results.Operation_Failed then
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      if Saved.Success and then Saved.Durable then
         Files.Model.Set_Error (Model, "");
      end if;
      Operation.Status :=
        (if Saved.Success then Files.Operation_Results.Operation_Success else Files.Operation_Results.Operation_Failed);
      Operation.Path := To_Unbounded_String (Settings_Path);
      Operation.Error_Key := Saved.Error_Key;

      return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
   end Save_Settings;
