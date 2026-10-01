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

package body Files.Job_Helpers is
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
   begin
      if Ada.Command_Line.Argument_Count = 1
        and then Ada.Command_Line.Argument (1) = "--files-scavenge"
      then
         if not Files.Job_Scavenger.Run then
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
         return True;
      end if;
      if Ada.Command_Line.Argument_Count not in 2 .. 3 then
         return False;
      end if;
      declare
         Mode      : constant String := Ada.Command_Line.Argument (1);
         Directory : constant String := Ada.Command_Line.Argument (2);
         Helper_Owner : Files.Job_Transports.Lease;
      begin
         if Mode in "--files-transfer" | "--files-operation" | "--files-refresh" | "--files-watch"
           | "--files-folder-size"
         then
            if Ada.Command_Line.Argument_Count /= 2
              or else Files.Job_Transports.Recorded_Identity (Directory) = ""
            then
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return True;
            end if;
            if not Files.Job_Transports.Join_Helper (Directory, Helper_Owner) then
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return True;
            end if;
            Files.Job_Context.Initialize (Directory);
            if Mode = "--files-transfer" then
               Files.Transfer_Jobs.Run_Helper (Directory);
            elsif Mode = "--files-operation" then
               Files.Operation_Jobs.Run_Helper (Directory);
            elsif Mode = "--files-refresh" then
               Files.Refresh_Jobs.Run_Helper (Directory);
            elsif Mode = "--files-folder-size" then
               Files.Folder_Size.Run_Helper (Directory);
            else
               Files.Refresh_Jobs.Run_Watch_Helper (Directory);
            end if;
            return True;
         elsif Mode = "--files-cleanup" then
            if Ada.Command_Line.Argument_Count /= 3 then
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return True;
            end if;
            if Files.Job_Cleanup.Run
              (Directory, Ada.Command_Line.Argument (3)) /=
                Files.Job_Cleanup.Cleanup_Removed
            then
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            end if;
            return True;
         end if;
      end;
      return False;
   end Run_If_Requested;
end Files.Job_Helpers;
