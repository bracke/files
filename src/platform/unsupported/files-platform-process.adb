package body Files.Platform.Process is

   --  Windows has no zombie: a process that has exited is gone once its handle is
   --  closed, and nothing is left for us to collect. Nothing to do.
   procedure Reap_Finished_Children is
   begin
      null;
   end Reap_Finished_Children;

end Files.Platform.Process;
