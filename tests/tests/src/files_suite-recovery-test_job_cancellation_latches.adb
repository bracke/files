with Files.Protocol_Names;
separate (Files_Suite.Recovery)
   --  A helper asks Files.Job_Context.Cancelled for every chunk it copies,
   --  so the marker is read only now and then: a cancel is seen within a
   --  check interval, and a cancel once seen is never taken back -- even if
   --  the marker went. A new job directory starts afresh.
   procedure Test_Job_Cancellation_Latches (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Job : Files.Process_Jobs.Session;
   begin
      Files.Process_Jobs.Reserve (Job);
      Files.Job_Context.Initialize (Files.Process_Jobs.Path (Job, ""));
      Assert (not Files.Job_Context.Cancelled, "a job nobody cancelled is not cancelled");

      Files.Process_Jobs.Cancel (Job);
      for Attempt in Files_Suite.Support.Polling loop
         exit when Files.Job_Context.Cancelled;
      end loop;
      Assert (Files.Job_Context.Cancelled, "the helper sees its parent's cancel");

      Ada.Directories.Delete_File (Files.Process_Jobs.Path (Job, Files.Protocol_Names.Cancel_File));
      Assert (Files.Job_Context.Cancelled, "a cancel once seen stays seen");

      Files.Job_Context.Initialize (Files.Process_Jobs.Path (Job, ""));
      Assert (not Files.Job_Context.Cancelled, "a job directory named again starts uncancelled");
      Files.Job_Context.Initialize ("");
      Assert (not Files.Job_Context.Cancelled, "outside a helper nothing is cancelled");
      Files.Process_Jobs.Reset (Job);
   exception
      when others =>
         Files.Job_Context.Initialize ("");
         Files.Process_Jobs.Reset (Job);
         raise;
   end Test_Job_Cancellation_Latches;
