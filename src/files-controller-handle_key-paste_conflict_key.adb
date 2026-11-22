separate (Files.Controller.Handle_Key)
--  While the paste-conflict dialog is open it owns the keyboard: the close
--  key (Escape unless rebound) cancels the whole paste and every other key is
--  swallowed so no command runs behind the modal.
procedure Paste_Conflict_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Is_Close_Key then
      --  As the dialog's Cancel button does, with its apply-to-all choice.
      Result := Handle_Conflict_Choice (Model, Settings, Files.Operations.Paste.Choice_Cancel);
   end if;
end Paste_Conflict_Key;
