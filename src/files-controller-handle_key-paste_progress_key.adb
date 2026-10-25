separate (Files.Controller.Handle_Key)
--  While a long paste is running the progress overlay owns the keyboard:
--  Escape requests cancellation (already-copied files are kept) and every
--  other key is swallowed so no command runs behind the modal-lite panel.
procedure Paste_Progress_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Paste_Execution_Is_Active (Model) then
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Operations.Cancel_Paste_Execution (Model);
         declare
            Finalized : constant Files.Operations.Operation_Result :=
              Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         begin
            Result := Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Finalized);
            return;
         end;
      end if;
      Result := Make_Result (Controller_Ignored);
      return;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Paste_Progress_Key;
