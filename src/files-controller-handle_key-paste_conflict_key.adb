separate (Files.Controller.Handle_Key)
--  While the paste-conflict dialog is open it owns the keyboard: Escape
--  cancels the whole paste and every other key is swallowed so no command
--  runs behind the modal.
procedure Paste_Conflict_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
      Result :=
        Make_Result
          (Controller_Command_Executed,
           Files.Commands.No_Command,
           Files.Operations.Resolve_Paste_Conflict
             (Model     => Model,
              Settings  => Settings,
              Choice    => Files.Operations.Choice_Cancel,
              Apply_All => False));
   end if;
end Paste_Conflict_Key;
