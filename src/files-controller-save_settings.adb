with Files.Operation_Results;
separate (Files.Controller)
   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Applied : constant Files.Settings.Settings_Parse_Result :=
        Files.Settings.Apply_Draft (Settings, Files.Model.Settings_Pane.Draft_Of (Model));
      Final     : Files.Settings.Settings_Model;
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
            Files.Settings_Form.Set_Draft (Model, Draft);
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
      Files.Settings_Form.Store_Shortcut_Overrides (Final);
      --  Save writes even an unchanged draft: it is how a save that failed
      --  earlier is tried again.
      Saved :=
        (if Files.Settings.Same_Content (Settings, Final)
         then Persisted (Model, Settings, Settings_Path)
         else Commit_Settings (Model, Settings, Final, Settings_Path));
      if not Files.Settings.Same_Content (Settings, Final) then
         Operation.Status := Files.Operation_Results.Operation_Failed;
         Operation.Error_Key := Saved.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      --  Apply the saved view mode and sort to the live model so a change made in
      --  the settings pane takes effect now, not only on the next launch. Do this
      --  before the refresh so the reload lists items in the new order.
      Files.Operations.Apply_Ui_State (Model, Final);

      Operation := Files.Operations.Refresh (Model, Settings);
      --  The pane shows what was saved -- every mapping row as the file
      --  holds it -- with each mapping editor still on the entry it was on,
      --  and a row just added and not yet filled in kept. Rebuilding the
      --  draft from the saved settings alone would send every group back to
      --  its first entry.
      Files.Settings_Form.Set_Draft
        (Model, Files.Settings.Draft_After_Save (Files.Model.Settings_Pane.Draft_Of (Model), Settings));
      --  The settings now applied, for the pane's next change. A write that
      --  failed was reported; Save (which always writes) tries it again.
      Files.Settings_Form.Mark_Saved (Model, Settings);
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
