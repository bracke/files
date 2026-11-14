separate (Files.Controller.Handle_Key)
--  While a long paste is running the progress overlay owns the keyboard:
--  Escape requests cancellation (already-copied files are kept) and every
--  other key is swallowed so no command runs behind the modal-lite panel.
procedure Paste_Progress_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
      Files.Foreground_Jobs.Cancel (Model);
      Result :=
        Make_Result
          (Controller_Command_Executed, Files.Commands.No_Command, Files.Foreground_Jobs.Advance (Model, Settings, 1));
   end if;
end Paste_Progress_Key;
