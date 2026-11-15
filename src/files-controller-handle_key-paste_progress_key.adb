separate (Files.Controller.Handle_Key)
--  While a long paste is running the progress overlay owns the keyboard:
--  the close key (Escape unless rebound) requests cancellation (already
--  copied files are kept) and every other key is swallowed so no command runs
--  behind the modal-lite panel.
procedure Paste_Progress_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Is_Close_Key then
      --  As the panel's Cancel button does.
      Result := Handle_Paste_Cancel (Model, Settings);
   end if;
end Paste_Progress_Key;
