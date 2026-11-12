separate (Files_Suite.Operations)
   procedure Test_Io_Error_Code_Per_Task (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Caller_Code : constant Integer := 28;
      Other_Code  : constant Integer := 13;
      Seen_Before : Integer := -1;
      Seen_After  : Integer := -1;
   begin
      Files.Io_Errors.Reset;
      Files.Io_Errors.Record_Code (Caller_Code);
      declare
         --  A background task (the orphan reaper, the scavenger's monitor)
         --  starting and failing an operation of its own.
         task Background;

         task body Background is
         begin
            Seen_Before := Files.Io_Errors.Last_Code;
            Files.Io_Errors.Reset;
            Files.Io_Errors.Record_Code (Other_Code);
            Seen_After := Files.Io_Errors.Last_Code;
         end Background;
      begin
         null;
      end;
      Assert (Seen_Before = 0, "a new task starts with no recorded code");
      Assert (Seen_After = Other_Code, "a task reads the code it recorded itself");
      Assert
        (Files.Io_Errors.Last_Code = Caller_Code,
         "another task's reset and capture leave the caller's code alone");
      Files.Io_Errors.Adopt_Code (Seen_After);
      Assert
        (Files.Io_Errors.Last_Code = Other_Code,
         "a worker's code handed back with Adopt_Code becomes the caller's");
      Files.Io_Errors.Reset;
      Assert (Files.Io_Errors.Last_Code = 0, "reset forgets the caller's code");
   end Test_Io_Error_Code_Per_Task;
