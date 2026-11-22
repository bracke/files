with Files.Jobs.Helper_Modes;
with Ada.Command_Line;
with Files.Jobs.Cleanup;
with Files.Jobs.Context;
with Files.Jobs.Scavenger;
with Files.Jobs.Transports;
with Files.Job_Drivers.Operation.Helper;
with Files.Transfer_Jobs;
with Files.Localization;
with Files.Refresh;
with Files.Folder_Size;
with Hostkit.Parent_Watch;

package body Files.Job_Drivers.Helpers is
   use Files.Jobs.Helper_Modes;
   use type Files.Jobs.Cleanup.Cleanup_Outcome;

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
            Files.Jobs.Scavenger.Set_Report_Label
              (Files.Localization.Text (Files.Jobs.Scavenger.Report_Label_Key));
            if Ada.Command_Line.Argument_Count /= 1 or else not Files.Jobs.Scavenger.Run then
               Fail;
            end if;
         when Files.Jobs.Helper_Modes.Cleanup =>
            if Ada.Command_Line.Argument_Count /= 3
              or else Files.Jobs.Cleanup.Run (Ada.Command_Line.Argument (2), Ada.Command_Line.Argument (3)) /=
                Files.Jobs.Cleanup.Cleanup_Removed
            then
               Fail;
            end if;
         when Files.Jobs.Helper_Modes.Transfer | Files.Jobs.Helper_Modes.Operation
            | Files.Jobs.Helper_Modes.Refresh | Watch | Files.Jobs.Helper_Modes.Folder_Size
         =>
            if Ada.Command_Line.Argument_Count /= 2 then
               Fail;
               return True;
            end if;
            declare
               Directory    : constant String := Ada.Command_Line.Argument (2);
               Helper_Owner : Files.Jobs.Transports.Lease;
            begin
               if Files.Jobs.Transports.Recorded_Identity (Directory) = ""
                 or else not Files.Jobs.Transports.Join_Helper (Directory, Helper_Owner)
               then
                  Fail;
                  return True;
               end if;
               Files.Jobs.Context.Initialize (Directory);
               case Mode is
                  when Files.Jobs.Helper_Modes.Transfer => Files.Transfer_Jobs.Run_Helper (Directory);
                  when Files.Jobs.Helper_Modes.Operation => Files.Job_Drivers.Operation.Helper.Run (Directory);
                  when Files.Jobs.Helper_Modes.Refresh => Files.Refresh.Run_Helper (Directory);
                  when Files.Jobs.Helper_Modes.Folder_Size => Files.Folder_Size.Run_Helper (Directory);
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
                        Files.Refresh.Run_Watch_Helper (Directory);
                     end;
                  when Scavenge | Files.Jobs.Helper_Modes.Cleanup => null;
               end case;
            end;
      end case;
      return True;
   end Run_If_Requested;
end Files.Job_Drivers.Helpers;
