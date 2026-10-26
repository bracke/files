separate (Files.Operations)
procedure Cancel_Paste_Execution
  (Model : in out Files.Model.Window_Model) is
   Requested : Boolean := True;
begin
   if not Files.Model.Paste_Execution_Is_Active (Model) then
      return;
   end if;
   --  Each cancel can fail (Process_Jobs refuses when it cannot write a
   --  trustworthy marker and stays retryable). Try both, and only show the
   --  operation as cancelled when both requests went through; otherwise the
   --  UI said "cancelled" while the helper ran to completion, and a second
   --  Cancel was never possible.
   begin
      Files.Transfer_Jobs.Cancel (Files.Model.Paste_Job (Model));
   exception
      when others => Requested := False;
   end;
   begin
      Files.Process_Jobs.Cancel (Files.Model.Background_Operation (Model));
   exception
      when others => Requested := False;
   end;
   Files.Model.Set_Paste_Cancelled (Model, Requested);
end Cancel_Paste_Execution;
