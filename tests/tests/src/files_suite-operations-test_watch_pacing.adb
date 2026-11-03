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

      Assert (Files.Refresh_Jobs.Retry_Due (Pacer, Start, False), "a listing that loaded may be re-read");
      Assert (Files.Refresh_Jobs.Retry_Due (Pacer, Start, True), "the first retry after a failure runs");
      Assert
        (not Files.Refresh_Jobs.Retry_Due (Pacer, Start + Retry - Ada.Real_Time.Milliseconds (1), True),
         "the next waits out the retry gap");
      Assert (Files.Refresh_Jobs.Retry_Due (Pacer, Start + Retry, True), "and then runs");
      Assert
        (Files.Refresh_Jobs.Retry_Due (Pacer, Start + Retry + Ada.Real_Time.Milliseconds (1), False),
         "a load that succeeds ends the back-off");
   end Test_Watch_Pacing;
