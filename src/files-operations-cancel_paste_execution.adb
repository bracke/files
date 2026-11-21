separate (Files.Operations)
procedure Cancel_Paste_Execution
  (Model : in out Files.Model.Window_Model) is
   Requested : Boolean := True;
begin
   if not Files.Model.Pasting.Execution_Is_Active (Model) then
      return;
   end if;
   --  A cancel can fail (Jobs.Process refuses when it cannot write a
   --  trustworthy marker and stays retryable). Only show the paste as
   --  cancelled when the request went through; otherwise the UI said
   --  "cancelled" while the helper ran to completion, and a second Cancel
   --  was never possible.
   begin
      Files.Jobs.Transfer.Cancel (Files.Model.Pasting.Job (Model));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Operations");
         Requested := False;
   end;
   Files.Model.Pasting.Set_Cancelled (Model, Requested);
end Cancel_Paste_Execution;
