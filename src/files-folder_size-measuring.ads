with Ada.Calendar;
with Ada.Real_Time;

--  Folder-size measurement in a cancellable helper process: one helper per
--  batch of directories (Max_Batch), each result published as it finishes.
--  Requests and polling only access private local transport files. All target
--  directory reads, classification and recursive traversal run in the helper,
--  using the same entry/depth guards as Files.File_System.Directory_Size.
package Files.Folder_Size.Measuring is

   --  A running helper is kept only while every directory it has still to
   --  report is wanted, as listed when it was asked for: one listed anew
   --  since is asked for again.
   --
   --  @param Scan Window-owned measurements.
   --  @param Targets Selected uncached directories, each with its listed time.
   procedure Set_Targets (Scan : in out Session; Targets : Target_Vectors.Vector);

   --  Ask again for one directory whose measurement came back stale (taken
   --  before the directory was listed as Listed), keeping the other targets.
   --
   --  @param Scan Window-owned measurements.
   --  @param Path Absolute path of the directory.
   --  @param Listed Its listed time now.
   procedure Measure_Again (Scan : in out Session; Path : String; Listed : Ada.Calendar.Time);

   --  @param Scan Measurements to abandon without waiting.
   procedure Cancel (Scan : in out Session);

   --  Collect what the helper has measured so far, and start the next batch
   --  once it has stopped.
   --
   --  @param Scan Window-owned measurements to poll.
   procedure Step (Scan : in out Session);

   --  How often finished measurements are handed over while more are coming:
   --  each one hands the window a snapshot to patch.
   Hand_Over_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (200);

   --  The measurements finished so far, at most once per Hand_Over_Interval
   --  while the helper is still working (all of them once it has stopped).
   --
   --  @param Scan Window-owned measurements.
   --  @param Now The current time.
   --  @param Taken The measurements handed over; empty when none are due.
   procedure Take_Due
     (Scan  : in out Session;
      Now   : Ada.Real_Time.Time;
      Taken : out Measurement_Vectors.Vector);

   --  Every finished measurement, due or not.
   --
   --  @param Scan Window-owned measurements.
   --  @param Taken The measurements handed over.
   procedure Take_All (Scan : in out Session; Taken : out Measurement_Vectors.Vector);

   --  Whether the targets were last set for these rows and this selection
   --  (Files.Model.Rows_Revision and Selection_Revision), so setting them
   --  again would ask for nothing new.
   --
   --  @param Scan Window-owned measurements.
   --  @param Rows The model's rows revision.
   --  @param Selection The model's selection revision.
   --  @return True when nothing has changed since.
   function Targets_Set_For (Scan : Session; Rows, Selection : Natural) return Boolean;

   --  Remember the rows and selection the targets were set for.
   --
   --  @param Scan Window-owned measurements.
   --  @param Rows The model's rows revision.
   --  @param Selection The model's selection revision.
   procedure Note_Targets_Set_For (Scan : in out Session; Rows, Selection : Natural);

   --  Internal helper entry point, dispatched before application startup.
   --  @param Directory Private transport directory containing the requested path.
   procedure Run_Helper (Directory : String);

private

   --  Set_Targets with no listed time known for any of Paths.
   --
   --  @param Scan Window-owned measurements.
   --  @param Paths Selected uncached directories.
   procedure Set_Targets (Scan : in out Session; Paths : Path_Vectors.Vector);

   --  Set_Targets with the one directory Path.
   --
   --  @param Scan The window's scan.
   --  @param Path Absolute path of the directory to measure.
   procedure Request (Scan : in out Session; Path : String);

   --  @param Scan Measurements to inspect.
   --  @return True when a helper is active.
   function Is_Active (Scan : Session) return Boolean;

   --  The most directories one helper measures.
   Max_Batch : constant := 256;

   --  Test seam: this many result reads fail as a result that will not open
   --  yet does. Read and written only by the thread that steps sessions.
   Test_Unreadable_Results : Natural := 0;

   --  Test seam: how many helpers the sessions have started (each a launch that
   --  did not fail). Read and written only by the thread that steps sessions.
   Test_Helper_Starts : Natural := 0;

   --  A finished helper's result that is there but will not open yet is read
   --  again on this many later steps before it is answered unmeasured.
   Finished_Read_Retries : constant := 4;

end Files.Folder_Size.Measuring;
