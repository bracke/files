separate (Files.Controller)
   function Disabled_Command_Result
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      --  The reason comes from the enablement rules themselves, so the message
      --  always names the check that actually failed.
      Error_Key : constant String :=
        Files.Commands.Reason_Key (Files.Commands.Status_Of (Id, Model).Reason);
   begin
      if Id in Files.Commands.Save_Settings_Command | Files.Commands.Reset_Settings_Command
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         return Settings_Closed_Result (Id, Model);
      elsif Error_Key = "" then
         --  Nothing worth saying (no history to undo, nothing to close).
         return Make_Result (Controller_Ignored, Id);
      end if;

      Files.Model.Set_Error (Model, Error_Key);
      return
        Make_Result
          (Controller_Ignored,
           Id,
           (Status    => Files.Operations.Operation_Disabled,
            Error_Key => To_Unbounded_String (Error_Key),
            Path      => Null_Unbounded_String,
            Action    => Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
            others    => <>));
   end Disabled_Command_Result;
