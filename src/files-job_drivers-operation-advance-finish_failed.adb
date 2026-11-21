separate (Files.Job_Drivers.Operation.Advance)
function Finish_Failed return Files.Operation_Results.Operation_Result is
begin
   --  Outcome decoding can fail before the request was read. Recover its
   --  identity independently so a same-view mutation is still reloaded,
   --  while an old job cannot disturb a newer view.
   begin
      Work := Read_Request (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File));
      Known_Kind := True;
      Same_View := Matches_Current_View (Work);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Job_Drivers.Operation");
         Same_View := False;
   end;
   Files.Model.End_Foreground_Job (Model);
   if not Settled then
      Files.Operations.Undo_Recording.Settle_History (Model);
   end if;
   if not Recovered then
      Recover_Undo (Model, Job);
   end if;
   --  Even an interrupted destructive operation may have changed its
   --  original view, but it must not refresh a different current view.
   Conclude_In_Origin (Failed_Key, Known_Kind);
   if Cancelled then
      return (Status => Files.Operation_Results.Operation_Success, others => <>);
   end if;
   return (Status => Files.Operation_Results.Operation_Failed,
           Error_Key => To_Unbounded_String (Failed_Key), others => <>);
end Finish_Failed;
