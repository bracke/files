with Files.Helper_Modes;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Files.Job_Cleanup;
with Files.Job_Context;
with Files.Job_Scavenger;
with Files.Job_Transports;
with Files.Operation_Jobs;
with Files.Transfer_Jobs;
with Files.Refresh_Jobs;
with Files.Folder_Size;
with Hostkit.Fs;
with Hostkit.Parent_Watch;

package body Files.Job_Helpers is
   use Files.Helper_Modes;
   use Ada.Strings.Unbounded;
   use type Files.Job_Cleanup.Cleanup_Outcome;
   use type Files.Job_Transports.Claim_Outcome;

   function Run_Cleanup
     (Directory          : String;
      Expected_Identity  : String;
      Attempt_Limit      : Positive := 8;
      Initial_Retry_Delay : Duration := 0.25;
      Maximum_Retry_Delay : Duration := 4.0) return Boolean
   is
   begin
      return Files.Job_Cleanup.Run
        (Directory, Expected_Identity, Attempt_Limit,
         Initial_Retry_Delay, Maximum_Retry_Delay) =
           Files.Job_Cleanup.Cleanup_Removed;
   end Run_Cleanup;

   function Run_If_Requested return Boolean is
      Found : Boolean := False;
      Mode  : Helper_Mode := Helper_Mode'First;

      procedure Fail is
      begin
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end Fail;
   begin
      if Ada.Command_Line.Argument_Count >= 1 then
         Mode := Mode_Of (Ada.Command_Line.Argument (1), Found);
      end if;
      if not Found then
         return False;
      end if;
      --  A helper flag is never a path to open: a mode given the wrong
      --  arguments fails here rather than starting a window. And every mode
      --  is answered below, or this does not compile.
      case Mode is
         when Scavenge =>
            if Ada.Command_Line.Argument_Count /= 1 or else not Files.Job_Scavenger.Run then
               Fail;
            end if;
         when Cleanup =>
            if Ada.Command_Line.Argument_Count /= 3
              or else Files.Job_Cleanup.Run (Ada.Command_Line.Argument (2), Ada.Command_Line.Argument (3)) /=
                Files.Job_Cleanup.Cleanup_Removed
            then
               Fail;
            end if;
         when Transfer | Operation | Refresh | Watch | Files.Helper_Modes.Folder_Size =>
            if Ada.Command_Line.Argument_Count /= 2 then
               Fail;
               return True;
            end if;
            declare
               Directory    : constant String := Ada.Command_Line.Argument (2);
               Helper_Owner : Files.Job_Transports.Lease;
            begin
               if Files.Job_Transports.Recorded_Identity (Directory) = ""
                 or else not Files.Job_Transports.Join_Helper (Directory, Helper_Owner)
               then
                  Fail;
                  return True;
               end if;
               Files.Job_Context.Initialize (Directory);
               case Mode is
                  when Transfer => Files.Transfer_Jobs.Run_Helper (Directory);
                  when Operation => Files.Operation_Jobs.Run_Helper (Directory);
                  when Refresh => Files.Refresh_Jobs.Run_Helper (Directory);
                  when Files.Helper_Modes.Folder_Size => Files.Folder_Size.Run_Helper (Directory);
                  when Watch =>
                     --  The other helpers finish on their own, and a transfer
                     --  must outlive a crashed window for its recovery to
                     --  mean anything. A watcher loops until cancelled and
                     --  serves only its window, so a window that died without
                     --  cancelling it would leave it polling forever. Where
                     --  the host cannot arrange it, cancellation still ends it.
                     declare
                        Ignored : constant Boolean := Hostkit.Parent_Watch.End_With_Parent;
                     begin
                        pragma Unreferenced (Ignored);
                        Files.Refresh_Jobs.Run_Watch_Helper (Directory);
                     end;
                  when Scavenge | Cleanup => null;
               end case;
            end;
      end case;
      return True;
   end Run_If_Requested;
end Files.Job_Helpers;
