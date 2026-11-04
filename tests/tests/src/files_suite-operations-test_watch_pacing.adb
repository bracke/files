with Ada.Real_Time;
separate (Files_Suite.Operations)
   procedure Test_Watch_Pacing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Real_Time.Time;
      Pacer : Files.Refresh_Jobs.Watch_Pacer;
      Start : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Gap   : constant Ada.Real_Time.Time_Span := Files.Refresh_Jobs.Watch_Refresh_Gap;
      Retry : constant Ada.Real_Time.Time_Span := Files.Refresh_Jobs.Load_Retry_Gap;
      function At_Ms (Ms : Natural) return Ada.Real_Time.Time is (Start + Ada.Real_Time.Milliseconds (Ms));
   begin
      Assert (not Files.Refresh_Jobs.Watch_Refresh_Due (Pacer, Start, False), "no change, no refresh");
      Assert (Files.Refresh_Jobs.Watch_Refresh_Due (Pacer, Start, True), "the first change refreshes at once");
      --  A file being written: a change every 50 ms.
      for Ms in 1 .. 20 loop
         Assert
           (not Files.Refresh_Jobs.Watch_Refresh_Due (Pacer, At_Ms (Ms * 50), True),
            "changes inside the gap wait");
      end loop;
      Assert
        (not Files.Refresh_Jobs.Watch_Refresh_Due (Pacer, Start + Gap - Ada.Real_Time.Milliseconds (1), False),
         "the owed refresh waits for the gap");
      Assert
        (Files.Refresh_Jobs.Watch_Refresh_Due (Pacer, Start + Gap, False),
         "and is paid once the gap has passed, with no new change");
      Assert
        (not Files.Refresh_Jobs.Watch_Refresh_Due (Pacer, Start + Gap + Gap, False),
         "nothing is owed after it");

      --  A change seen while a read runs stays owed and is paid after it.
      Files.Refresh_Jobs.Owe_Watch_Refresh (Pacer, True);
      Assert
        (Files.Refresh_Jobs.Watch_Refresh_Due (Pacer, Start + Gap + Gap + Gap, False),
         "a change owed during a read is refreshed once the gap allows");

      Assert (Files.Refresh_Jobs.Retry_Due (Pacer, Start, False), "a listing that loaded may be re-read");
      Assert (Files.Refresh_Jobs.Retry_Due (Pacer, Start, True), "the first retry after a failure runs");
      Assert
        (not Files.Refresh_Jobs.Retry_Due (Pacer, Start + Retry - Ada.Real_Time.Milliseconds (1), True),
         "the next waits out the retry gap");
      Assert (Files.Refresh_Jobs.Retry_Due (Pacer, Start + Retry, True), "and then runs");
      Assert
        (Files.Refresh_Jobs.Retry_Due (Pacer, Start + Retry + Ada.Real_Time.Milliseconds (1), False),
         "a load that succeeds ends the back-off");

      --  The window's step, as the event loop takes it.
      declare
         use type Files.Refresh_Jobs.Watch_Step_Action;
         Step_Pacer : Files.Refresh_Jobs.Watch_Pacer;
         Polled     : Boolean;

         function Step
           (Ms : Natural; Changed : Boolean; Reading : Boolean := False; Failed : Boolean := False;
            Poll_Due : Boolean := False) return Files.Refresh_Jobs.Watch_Step_Action is
           (Files.Refresh_Jobs.Watch_Step (Step_Pacer, At_Ms (Ms), Changed, Reading, Failed, Poll_Due, Polled));
      begin
         Assert (Step (0, Changed => False) = Files.Refresh_Jobs.Watch_Wait and then not Polled,
                 "nothing heard and no poll due: wait");
         Assert (Step (0, Changed => True, Reading => True) = Files.Refresh_Jobs.Watch_Wait,
                 "a change heard while a read runs starts nothing");
         Assert (Step (10, Changed => False) = Files.Refresh_Jobs.Watch_Refresh,
                 "and is paid once the read is in");
         Assert (Step (20, Changed => True) = Files.Refresh_Jobs.Watch_Wait,
                 "a change inside the gap waits");
         Assert (Step (30, Changed => False, Poll_Due => True) = Files.Refresh_Jobs.Watch_Refresh and then Polled,
                 "the timed re-read still runs inside the gap");
         Assert
           (Step (10 + Natural (Ada.Real_Time.To_Duration (Gap) * 1000.0), Changed => False)
            = Files.Refresh_Jobs.Watch_Refresh,
            "the owed change is paid once the gap has passed");
         Assert (Step (50_000, Changed => False, Poll_Due => True) = Files.Refresh_Jobs.Watch_Refresh
                 and then Polled,
                 "with nothing heard, the due timed re-read runs and takes its turn");
         Assert
           (Step (50_010, Changed => False, Failed => True, Poll_Due => True) = Files.Refresh_Jobs.Watch_Refresh,
            "a failed listing is re-read once");
         Assert (Step (50_020, Changed => False, Failed => True, Poll_Due => True) = Files.Refresh_Jobs.Watch_Wait
                 and then Polled,
                 "and then waits out the retry gap, the poll's turn taken all the same");
      end;
   end Test_Watch_Pacing;
