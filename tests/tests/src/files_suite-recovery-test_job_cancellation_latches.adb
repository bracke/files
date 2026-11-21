with Files.Protocol_Names;
with Files_Suite.Support.Timing;
separate (Files_Suite.Recovery)
   --  A helper asks Files.Jobs.Context.Cancelled for every chunk it copies,
   --  so the marker is read only now and then: a cancel is seen within a
   --  check interval, and a cancel once seen is never taken back -- even if
   --  the marker went. A new job directory starts afresh.
   procedure Test_Job_Cancellation_Latches (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Job : Files.Jobs.Process.Session;
   begin
      Files.Jobs.Process.Reserve (Job);
      Files.Jobs.Context.Initialize (Files.Jobs.Process.Path (Job, ""));
      Assert (not Files.Jobs.Context.Cancelled, "a job nobody cancelled is not cancelled");

      Files.Jobs.Process.Cancel (Job);
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Files.Jobs.Context.Cancelled;
      end loop;
      Assert (Files.Jobs.Context.Cancelled, "the helper sees its parent's cancel");

      Ada.Directories.Delete_File (Files.Jobs.Process.Path (Job, Files.Protocol_Names.Cancel_File));
      Assert (Files.Jobs.Context.Cancelled, "a cancel once seen stays seen");

      Files.Jobs.Context.Initialize (Files.Jobs.Process.Path (Job, ""));
      Assert (not Files.Jobs.Context.Cancelled, "a job directory named again starts uncancelled");
      Files.Jobs.Context.Initialize ("");
      Assert (not Files.Jobs.Context.Cancelled, "outside a helper nothing is cancelled");
      Files.Jobs.Process.Reset (Job);
   exception
      when others =>
         Files.Jobs.Context.Initialize ("");
         Files.Jobs.Process.Reset (Job);
         raise;
   end Test_Job_Cancellation_Latches;
