separate (Files.Operations)
   function Open_Action_Policy return Open_Action_Execution_Policy is
   begin
      return
        (Uses_Argument_Vector       => True,
         Shell_Requires_Explicit_Opt_In => True,
         Checks_Executable_Before_Spawn => True,
         Tracks_Execution_Attempt  => True,
         Tracks_Exit_Status        => True,
         --  A detached launch really is asynchronous now: Files.Launcher starts the
         --  process and returns, instead of blocking on a shell that backgrounded it.
         Runs_Asynchronously       => True,
         Supports_Cancellation     => False,
         Rejects_Unsafe_Placeholders => True,
         Reports_Missing_Action    => True,
         Reports_Missing_Executable => True,
         Captures_Executable_Discovery => True,
         Captures_Process_Result       => True,
         Quotes_Shell_Arguments        => True,
         Preserves_Vector_Boundaries   => True,
         Multi_File_Deterministic      => True);
   end Open_Action_Policy;
