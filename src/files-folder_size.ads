with Ada.Containers.Vectors;
with Ada.Real_Time;
with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Process_Jobs;

--  Folder-size measurement in a cancellable helper process: one helper per
--  batch of directories (Max_Batch), each result published as it finishes.
--  Requests and polling only access private local transport files. All target
--  directory reads, classification and recursive traversal run in the helper,
--  using the same entry/depth guards as Files.File_System.Directory_Size.
package Files.Folder_Size is

   --  A set of directories to measure (absolute paths).
   package Path_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Ada.Strings.Unbounded.Unbounded_String,
      "="          => Ada.Strings.Unbounded."=");

   --  One window's independent queue and helper ownership.
   type Session is private;

   --  @param Scan Window-owned measurements.
   --  @param Paths Selected uncached directories.
   procedure Set_Targets (Scan : in out Session; Paths : Path_Vectors.Vector);

   --  @param Scan Measurements to abandon without waiting.
   procedure Cancel (Scan : in out Session);

   --  Collect what the helper has measured so far, and start the next batch
   --  once it has stopped.
   --
   --  @param Scan Window-owned measurements to poll.
   procedure Step (Scan : in out Session);

   --  One finished measurement.
   type Measurement is record
      Path   : Ada.Strings.Unbounded.Unbounded_String;
      Result : Files.File_System.Directory_Size_Result;
   end record;

   package Measurement_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Measurement);

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

   --  @param Scan Measurements to inspect.
   --  @return True when a helper is active.
   function Is_Active (Scan : Session) return Boolean;

   --  Set_Targets with the one directory Path.
   --
   --  @param Scan The window's scan.
   --  @param Path Absolute path of the directory to measure.
   procedure Request (Scan : in out Session; Path : String);

   --  Internal helper entry point, dispatched before application startup.
   --  @param Directory Private transport directory containing the requested path.
   procedure Run_Helper (Directory : String);

private
   --  The most directories one helper measures.
   Max_Batch : constant := 256;

   type Session is record
      Job : Files.Process_Jobs.Session;
      --  The running helper's directories, in its order, and the index of
      --  the next result it will publish (result-<index>).
      Batch       : Path_Vectors.Vector;
      Next_Result : Positive := 1;
      --  Requested directories not yet given to a helper.
      Targets     : Path_Vectors.Vector;
      Done_Queue  : Measurement_Vectors.Vector;
      Handed_At   : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Set_For_Rows      : Natural := Natural'Last;
      Set_For_Selection : Natural := Natural'Last;
   end record;
end Files.Folder_Size;
