with Files.Model.Jobs;
with Files.Io_Errors;
with Files.Operation_Results;
with Files.Operations;
with Files.Jobs.Process;

package body Files.Application.Windows.Watch is
   use type Ada.Real_Time.Time;

   --  How often a folder without a native watch is re-read for changes.
   File_Watch_Poll_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);
   --  With the watch helper reporting changes (Watch_Is_Native), the re-read
   --  only covers what it can miss (a change made over the network to a
   --  mounted folder).
   --  Each re-read stats every entry, so in a large folder it is not free.
   Native_Watch_Poll_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (10);

   function Drain_Native_Watch
     (Runtime : in out Runtime_Window)
      return Boolean is
   begin
      --  Native registration and storage reads happen in the helper process.
      Files.Refresh.Watch_Path
        (Runtime.Watch, Files.Model.Current_Path (Runtime.Model));

      return Files.Refresh.Poll_Watch (Runtime.Watch);
   end Drain_Native_Watch;

   procedure Poll
     (Runtime : in out Runtime_Window)
   is
      Now    : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      --  A failed refresh leaves its error on the model's error line, and an
      --  applied listing is drawn from the model: neither answer is needed.
      Result : Files.Operation_Results.Operation_Result;
      pragma Unreferenced (Result);
      Refreshed : Boolean;
      pragma Unreferenced (Refreshed);
   begin
      if Runtime.Handle = null then
         return;
      end if;
      if not Glfw.Windows.Initialized (As_Window (Runtime.Handle))
        or else Glfw.Windows.Should_Close (As_Window (Runtime.Handle))
      then
         Release_Window_Jobs (Runtime.Model, Runtime.Watch);
         return;
      end if;

      if Files.Model.Foreground_Job_Is_Active (Runtime.Model) then
         Files.Refresh.Cancel (Runtime.Model);
         return;
      end if;
      Refreshed := Files.Refresh.Advance (Runtime.Model, Runtime.Settings);
      Reveal_Pending_Selection (Runtime);
      Files.Refresh.Resume_Owed (Runtime.Model, Runtime.Settings);

      declare
         Changed     : constant Boolean := Drain_Native_Watch (Runtime);
         Load_Failed : constant Boolean :=
           Files.Model.Last_Error_Key (Runtime.Model) = Files.Io_Errors.Directory_Load_Key;
         Polled      : Boolean;
      begin
         --  A burst of writes is paced to one reload per gap, the last one
         --  owed and paid; a listing that cannot be read is retried slowly.
         case Files.Refresh.Watch_Step
           (Pacer       => Runtime.Watch_Pacing,
            Now         => Now,
            Changed     => Changed,
            Read_Active => Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Runtime.Model)),
            Load_Failed => Load_Failed,
            Poll_Due    =>
              Now >= Runtime.Last_Watch_Poll + File_Watch_Poll_Interval
              and then (not Files.Refresh.Watch_Is_Native (Runtime.Watch)
                        or else Now >= Runtime.Last_Watch_Poll + Native_Watch_Poll_Interval),
            Polled      => Polled)
         is
            when Files.Refresh.Watch_Refresh =>
               Result := Files.Operations.Refresh_If_Changed (Runtime.Model, Runtime.Settings);
            when Files.Refresh.Watch_Wait =>
               null;
         end case;
         if Polled then
            Runtime.Last_Watch_Poll := Now;
         end if;
      end;
   end Poll;

end Files.Application.Windows.Watch;
