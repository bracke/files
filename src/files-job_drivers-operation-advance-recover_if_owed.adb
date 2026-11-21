separate (Files.Job_Drivers.Operation.Advance)
procedure Recover_If_Owed (Choice : Disposition) is
begin
   if Choice /= Discard
     and then (History_Lost or else Done.Result.Status /= Files.Operation_Results.Operation_Success)
   then
      Recover_Undo
        (Model, Job,
         Undone =>
           History_Lost and then not Cancelled
           and then Done.Result.Status = Files.Operation_Results.Operation_Success);
      Recovered := True;
   end if;
end Recover_If_Owed;
