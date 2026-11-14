with Files.Operations;
with Ada.Strings.Unbounded;
with Files.Diagnostics;
with Files.Operation_Jobs;
with Files.Process_Jobs;

package body Files.Foreground_Jobs is

   function Advance
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Files.Operation_Results.Operation_Result is
   begin
      case Files.Model.Foreground_Job (Model) is
         when Files.Model.Paste_Job =>
            return Files.Operations.Advance_Paste_Execution (Model, Settings, Max_Items);
         when Files.Model.Operation_Job =>
            return Files.Operation_Jobs.Advance (Model, Settings);
         when Files.Model.No_Foreground_Job =>
            return (Status => Files.Operation_Results.Operation_Success,
                    Path   => Ada.Strings.Unbounded.To_Unbounded_String (Files.Model.Current_Path (Model)),
                    others => <>);
      end case;
   end Advance;

   procedure Cancel (Model : in out Files.Model.Window_Model) is
   begin
      case Files.Model.Foreground_Job (Model) is
         when Files.Model.Paste_Job =>
            Files.Operations.Cancel_Paste_Execution (Model);
         when Files.Model.Operation_Job =>
            --  Refused when no trustworthy marker could be written: it stays
            --  retryable, and a later Cancel asks again.
            begin
               Files.Process_Jobs.Cancel (Files.Model.Background_Operation (Model));
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.Foreground_Jobs");
            end;
         when Files.Model.No_Foreground_Job =>
            null;
      end case;
   end Cancel;

end Files.Foreground_Jobs;
