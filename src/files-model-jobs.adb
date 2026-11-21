with Ada.Strings.Unbounded;
with Files.Model.Support;

package body Files.Model.Jobs is
   use Ada.Strings.Unbounded;

   function Foreground_Progress_Of (Model : Window_Model) return Foreground_Progress is
     (case Model.Foreground_Kind is
         when No_Foreground_Job => (others => <>),
         when Paste_Job =>
           (Done      => Model.Paste_Exec.Done,
            Total     => Model.Paste_Exec.Total,
            Name      => Model.Paste_Exec.Current,
            Moving    => Files.File_System_Types."=" (Model.Paste_Exec.Mode, Files.File_System_Types.Drop_Move),
            Label_Key => Null_Unbounded_String),
         when Operation_Job =>
           (Done      => 0,
            Total     => 1,
            Name      => Model.Operation_Name,
            Moving    => False,
            Label_Key => Model.Operation_Label_Key));

   procedure Begin_Operation_Job
     (Model : in out Window_Model; Job : Files.Jobs.Process.Session; Label_Key : String) is
   begin
      End_Foreground_Job (Model);
      Support.Claim_Overlay_Input (Model);
      Model.Foreground_Kind := Operation_Job;
      Model.Operation_Job := Job;
      Model.Operation_Label_Key := To_Unbounded_String (Label_Key);
      Model.Operation_Name := To_Unbounded_String (Current_Path (Model));
      Support.Touch (Model);
   end Begin_Operation_Job;

   function Background_Operation (Model : Window_Model) return Files.Jobs.Process.Session is (Model.Operation_Job);

   procedure Defer_Operation_Merge (Model : in out Window_Model; Deadline : Ada.Real_Time.Time) is
   begin
      Model.Operation_Merge_Deferred := True;
      Model.Operation_Merge_Deadline := Deadline;
   end Defer_Operation_Merge;

   function Operation_Merge_Deferred (Model : Window_Model) return Boolean is (Model.Operation_Merge_Deferred);

   function Operation_Merge_Deadline (Model : Window_Model) return Ada.Real_Time.Time is
     (Model.Operation_Merge_Deadline);

   procedure Set_Background_Refresh (Model : in out Window_Model; Job : Files.Jobs.Process.Session) is
   begin
      Model.Refresh_Job := Job;
   end Set_Background_Refresh;

   function Background_Refresh (Model : Window_Model) return Files.Jobs.Process.Session is (Model.Refresh_Job);

end Files.Model.Jobs;
