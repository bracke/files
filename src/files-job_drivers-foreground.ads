with Files.Operation_Results;
with Files.Model;
with Files.Settings;

--  Driving the window's modal job, whichever it is (Files.Model.Foreground_Job):
--  a paste, advanced by Files.Operations, or an operation, by
--  Files.Job_Drivers.Operation. The one place that tells them apart, so neither
--  drives the other.
package Files.Job_Drivers.Foreground is

   --  Advance the modal job by up to Max_Items steps, finishing it when it is
   --  done.
   --
   --  @param Model Window running the job.
   --  @param Settings Settings used for the finishing directory reload.
   --  @param Max_Items Most paste actions to process this call; an operation
   --    is polled once.
   --  @return As Files.Operations.Advance_Paste_Execution or
   --    Files.Job_Drivers.Operation.Advance; a no-op Success with no job.
   function Advance
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Files.Operation_Results.Operation_Result;

   --  Ask the modal job to stop. What it finished is kept; the next Advance
   --  finishes over that. Nothing with no job.
   --
   --  @param Model Window running the job.
   procedure Cancel (Model : in out Files.Model.Window_Model);

end Files.Job_Drivers.Foreground;
