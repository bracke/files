separate (Files.Model)
procedure Cancel_Paste_Execution
  (Model : in out Window_Model) is
   Requested : Boolean := True;
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   --  Each cancel can fail (Process_Jobs refuses when it cannot write a
   --  trustworthy marker and stays retryable). Try both, and only show the
   --  operation as cancelled when both requests went through; otherwise the
   --  UI said "cancelled" while the helper ran to completion, and a second
   --  Cancel was never possible.
   begin
      Files.Transfer_Jobs.Cancel (Model.Paste_Exec_Job);
   exception
      when others => Requested := False;
   end;
   begin
      Files.Process_Jobs.Cancel (Model.Operation_Job);
   exception
      when others => Requested := False;
   end;
   Model.Paste_Exec.Cancelled := Requested;
end Cancel_Paste_Execution;
