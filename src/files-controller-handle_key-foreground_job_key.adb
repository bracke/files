separate (Files.Controller.Handle_Key)
--  While a foreground job (a long paste or an operation) runs, its progress
--  overlay owns the keyboard: the close key (Escape unless rebound) requests
--  cancellation (what is done is kept) and every other key is swallowed so
--  no command runs behind the modal-lite panel.
procedure Foreground_Job_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Is_Close_Key then
      --  As the panel's Cancel button does.
      Result := Handle_Foreground_Job_Cancel (Model, Settings);
   end if;
end Foreground_Job_Key;
