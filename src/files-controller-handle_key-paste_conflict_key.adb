separate (Files.Controller.Handle_Key)
--  While the paste-conflict dialog is open it owns the keyboard: Escape
--  cancels the whole paste and every other key is swallowed so no command
--  runs behind the modal.
procedure Paste_Conflict_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Paste_Conflict_Is_Active (Model) then
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         declare
            Cancelled : constant Files.Operations.Operation_Result :=
              Files.Operations.Resolve_Paste_Conflict
                (Model     => Model,
                 Settings  => Settings,
                 Choice    => Files.Operations.Choice_Cancel,
                 Apply_All => False);
         begin
            Result := Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Cancelled);
            return;
         end;
      end if;
      Result := Make_Result (Controller_Ignored);
      return;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Paste_Conflict_Key;
