with Ada.Real_Time;
with Files.Jobs.Process;

--  The window's helper jobs: the modal operation (Files.Jobs.Operation) with
--  its progress and deferred journal merge, and the nonmodal directory read
--  (Files.Jobs.Refresh). A child of its own so Files.Model's spec need not
--  name the helper sessions; Files.Model.End_Foreground_Job ends either
--  modal job.
package Files.Model.Jobs is

   --  What the progress overlay shows of the modal job.
   type Foreground_Progress is record
      --  Writes finished and to do: an operation is one step.
      Done      : Natural := 0;
      Total     : Natural := 0;
      --  The item being written, or the folder an operation runs in.
      Name      : UString;
      --  A paste that moves rather than copies.
      Moving    : Boolean := False;
      --  An operation's command caption key; empty for a paste.
      Label_Key : UString;
   end record;

   --  @param Model Window to inspect.
   --  @return Its modal job's progress (all zero with no job).
   function Foreground_Progress_Of (Model : Window_Model) return Foreground_Progress;

   --  Run Job as the window's modal operation: it owns the input and shows
   --  progress under Label_Key until End_Foreground_Job.
   --
   --  @param Model Window to update; it runs no other modal job.
   --  @param Job The operation's started helper session.
   --  @param Label_Key Localized command caption for the progress overlay.
   procedure Begin_Operation_Job
     (Model : in out Window_Model; Job : Files.Jobs.Process.Session; Label_Key : String);

   --  @param Model Window to inspect.
   --  @return The modal operation's helper session; inactive for a paste.
   function Background_Operation (Model : Window_Model) return Files.Jobs.Process.Session;

   --  Wait for the modal operation's finished helper's history journal, not
   --  readable yet, until Deadline (Files.Jobs.Operation). Forgotten with
   --  the job: End_Foreground_Job, a new modal job, or the window going.
   --
   --  @param Model Window running a modal operation.
   --  @param Deadline When the journal is given up if still unreadable.
   procedure Defer_Operation_Merge (Model : in out Window_Model; Deadline : Ada.Real_Time.Time);

   --  @param Model Window to inspect.
   --  @return True while its modal operation's journal is waited for.
   function Operation_Merge_Deferred (Model : Window_Model) return Boolean;

   --  @param Model Window to inspect.
   --  @return When that wait ends; meaningful while Operation_Merge_Deferred.
   function Operation_Merge_Deadline (Model : Window_Model) return Ada.Real_Time.Time;

   --  @param Model Window whose nonmodal directory-read session to replace.
   --  @param Job Shared helper session, or empty to cancel the pending read.
   --  Transport changes do not change the visible model revision.
   procedure Set_Background_Refresh (Model : in out Window_Model; Job : Files.Jobs.Process.Session);

   --  @param Model Window owning a nonmodal directory-read helper.
   --  @return Shared refresh session, or an empty session.
   function Background_Refresh (Model : Window_Model) return Files.Jobs.Process.Session;

end Files.Model.Jobs;
