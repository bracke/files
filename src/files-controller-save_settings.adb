separate (Files.Controller)
   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Applied : constant Files.Settings.Settings_Parse_Result :=
        Files.Settings.Apply_Draft (Settings, Files.Model.Settings_Draft_Of (Model));
      Final     : Files.Settings.Settings_Model;
      Saved     : Files.Settings.Settings_Write_Result;
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      if not Files.Model.Settings_Pane_Is_Open (Model) then
         return Settings_Closed_Result (Files.Commands.Save_Settings_Command, Model, Settings_Path);
      elsif not Applied.Success then
         declare
            Draft : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
         begin
            Draft.Valid := False;
            Draft.Error_Key := Applied.Error_Key;
            Files.Model.Set_Settings_Draft (Model, Draft);
         end;
         Files.Model.Set_Error (Model, To_String (Applied.Error_Key));
         Operation.Status := Files.Operations.Operation_Failed;
         Operation.Error_Key := Applied.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      --  The same policy as every other settings change: apply it for the
      --  session, then save; a failed or non-durable save is reported, not
      --  undone.
      Final := Applied.Settings;
      Store_Shortcut_Overrides (Final);
      Settings := Final;

      --  Apply the saved view mode and sort to the live model so a change made in
      --  the settings pane takes effect now, not only on the next launch. Do this
      --  before the refresh so the reload lists items in the new order.
      Files.Operations.Apply_Ui_State (Model, Final);

      Operation := Files.Operations.Refresh (Model, Settings);
      Saved := Persisted (Model, Settings, Settings_Path);
      Files.Model.Set_Settings_Draft (Model, Files.Settings.Make_Draft (Settings));
      if Operation.Status = Files.Operations.Operation_Failed then
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      if Saved.Success and then Saved.Durable then
         Files.Model.Set_Error (Model, "");
      end if;
      Operation.Status :=
        (if Saved.Success then Files.Operations.Operation_Success else Files.Operations.Operation_Failed);
      Operation.Path := To_Unbounded_String (Settings_Path);
      Operation.Error_Key := Saved.Error_Key;

      return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
   end Save_Settings;
