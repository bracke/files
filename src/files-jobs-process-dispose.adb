separate (Files.Jobs.Process)
   procedure Dispose (Item : in out State_Access; Stopping : Boolean := False) is
      Stages : constant String := Hostkit.Fs.Join (To_String (Item.Directory), Files.Protocol_Names.Stages_Directory);

      function Launch_Cleanup return Boolean is
         Arguments : Hostkit.String_Vectors.Vector;
      begin
         if Stopping then
            return False;
         end if;
         Arguments.Append (Item.Directory);
         Arguments.Append (Item.Identity);
         Item.Cleanup := (others => <>);
         if not Start_Helper (Files.Jobs.Helper_Modes.Cleanup, Arguments, Item.Cleanup) then
            return False;
         end if;
         Test_Cleanup_Launches :=
           (if Test_Cleanup_Launches = Natural'Last then 0 else Test_Cleanup_Launches + 1);
         Note_Started (Item.Cleanup);
         return True;
      end Launch_Cleanup;

      procedure Retain_For_Cleanup (Delay_Retry : Boolean) is
      begin
         if Stopping then
            Destroy (Item);
            return;
         end if;
         --  The helper is gone; only the cleanup worker is watched from here.
         Item.Helper := (others => <>);
         Item.Cancelled := False;
         Item.Detached := False;
         if Delay_Retry then
            Item.Cleanup_Retry_At := Ada.Real_Time.Clock + Cleanup_Retry_Delay;
         end if;
         --  Dispose runs only in the reaper task, so the reaper is alive:
         --  its globals (Reaper, Reaper_Stopped) belong to the main task.
         Submit_Or_Abandon (Item);
      end Retain_For_Cleanup;

      procedure Defer_After_Cleanup_Failure is
      begin
         Item.Cleanup_Failures := Item.Cleanup_Failures + 1;
         if Item.Cleanup_Failures >= Cleanup_Failure_Limit then
            --  The marker and staging journal are the durable retry state.
            --  Drop only the in-memory owner so a permanent refusal cannot
            --  create an endless stream of cleanup workers in this process.
            Destroy (Item);
         else
            Retain_For_Cleanup (Delay_Retry => True);
         end if;
      end Defer_After_Cleanup_Failure;

      --  Look at the job in order, stopping at the first fact that settles
      --  it: a closed queue, a cleanup worker (collected if it exited), stage
      --  records, then a direct removal of the transport when none are there.
      function Gather return Disposal_Facts is
         Facts : Disposal_Facts;
      begin
         if Orphan_Queue.Closed then
            Facts.Queue_Closed := True;
            return Facts;
         end if;
         if Item.Cleanup.Started and then not Item.Cleanup.Finished then
            declare
               Status : Hostkit.Spawn.Status;
            begin
               if not Collect (Item.Cleanup, Status) then
                  Facts.Cleanup :=
                    (if Files.Timing.Elapsed (Ada.Real_Time.Clock, Item.Cleanup.Started_At, Cleanup_Timeout)
                     then Overdue
                     else Running);
               elsif Status.State = Hostkit.Spawn.Wait_Exited
                 and then Status.Exit_Code = 0 and then Transport_Gone (Item)
               then
                  --  A successful exit is only authoritative once the
                  --  transport has actually disappeared.
                  Facts.Cleanup := Exited_Done;
               else
                  Facts.Cleanup := Exited_Failed;
               end if;
            end;
            return Facts;
         end if;
         --  Stage records that may be there (the host will not say) are kept
         --  as surely as present ones: the transport is the only pointer to
         --  the staged entries they name.
         if not Files.IO.Fs_Primitives.Entry_Is_Absent (Stages) then
            Facts.Stages_Present := True;
            Facts.Retry_Due := Ada.Real_Time.Clock >= Item.Cleanup_Retry_At;
            return Facts;
         end if;
         begin
            Test_Removal_Attempts :=
              (if Test_Removal_Attempts = Natural'Last then 0 else Test_Removal_Attempts + 1);
            Facts.Removed :=
              Files.Jobs.Transports.Matches (To_String (Item.Directory), To_String (Item.Identity))
              and then Files.Jobs.Storage.Delete_Transport_Entry
                (To_String (Item.Directory), To_String (Item.Identity));
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Jobs.Process");
         end;
         --  A transport without staging records can still resist removal: an
         --  unreadable child, a sharing violation, or a transient filesystem
         --  error is enough. Then the same independent cleanup worker takes
         --  it, so the failure is retried during application idleness instead
         --  of being forgotten when this state is freed.
         if not Facts.Removed then
            Facts.Transport_Gone := Transport_Gone (Item);
         end if;
         return Facts;
      end Gather;
   begin
      --  From here onward the job no longer has a live owner. Releasing the
      --  lease lets this process or a later startup recover the transport if
      --  the immediate guarded cleanup cannot finish.
      Files.Jobs.Transports.Release (Item.Owner);
      case Decide (Gather, Stopping) is
         when Destroy_State =>
            Destroy (Item);
         when Retain =>
            Retain_For_Cleanup (Delay_Retry => False);
         when Stop_And_Retain =>
            Stop (Item.Cleanup);
            Retain_For_Cleanup (Delay_Retry => False);
         when Defer_Failure =>
            Defer_After_Cleanup_Failure;
         when Launch_Then_Retain =>
            if Launch_Cleanup then
               Retain_For_Cleanup (Delay_Retry => False);
            else
               Defer_After_Cleanup_Failure;
            end if;
      end case;
   end Dispose;
