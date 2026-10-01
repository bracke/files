with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Process_Jobs;

--  Folder-size measurement in a cancellable helper process.
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

   --  @param Scan Window-owned measurements to poll.
   --  @param Budget Zero skips polling, nonzero polls once.
   procedure Step (Scan : in out Session; Budget : Natural := 4000);

   --  @param Scan Window-owned completed results.
   --  @param Path Measured directory.
   --  @param Result Measured totals.
   --  @param Available True when a result was collected.
   procedure Take
     (Scan : in out Session;
      Path : out Ada.Strings.Unbounded.Unbounded_String;
      Result : out Files.File_System.Directory_Size_Result;
      Available : out Boolean);

   --  @param Scan Measurements to inspect.
   --  @return True when a helper is active.
   function Is_Active (Scan : Session) return Boolean;

   --  @param Scan Measurements to inspect.
   --  @return Active directory, or empty when idle.
   function Target_For_Test (Scan : Session) return String;

   --  Set the directories to measure. The walk already in progress keeps running
   --  when its directory is still in Paths; otherwise it is abandoned. Every
   --  other path in Paths is queued and measured one at a time, so a multi-item
   --  selection produces one result per directory. Finished-but-untaken results
   --  are preserved.
   --
   --  @param Paths Absolute paths of the directories to measure.
   procedure Set_Targets (Paths : Path_Vectors.Vector);

   --  Convenience wrapper for measuring a single directory.
   --
   --  @param Path Absolute path of the directory to measure.
   procedure Request (Path : String);

   --  Abandon the walk in progress and the queue, if any. Finished-but-untaken
   --  results are left intact so pending measurements can still be collected.
   procedure Cancel;

   --  Poll the helper without waiting and collect a completed result.
   --  @param Budget Retained for callers; zero skips polling, nonzero polls once.
   procedure Step (Budget : Natural := 4000);

   --  Collect one finished measurement. When one is available it is returned and
   --  removed so it is delivered exactly once; call repeatedly to drain several.
   --
   --  @param Path Directory the measurement is for (valid when Available).
   --  @param Result The measured totals (valid when Available).
   --  @param Available True when a finished measurement was returned.
   procedure Take
     (Path      : out Ada.Strings.Unbounded.Unbounded_String;
      Result    : out Files.File_System.Directory_Size_Result;
      Available : out Boolean);

   --  Return whether a measurement is currently in progress. For tests.
   --
   --  @return True when a walk is active (requested and not yet finished).
   function Is_Active return Boolean;

   --  Return the path of the measurement in progress, or "" when idle. For
   --  tests.
   --
   --  @return The active target path, or the empty string when idle.
   function Target_For_Test return String;

   --  Internal helper entry point, dispatched before application startup.
   --  @param Directory Private transport directory containing the requested path.
   procedure Run_Helper (Directory : String);

private
   type Finished_Measurement is record
      Path : Ada.Strings.Unbounded.Unbounded_String;
      Result : Files.File_System.Directory_Size_Result;
   end record;
   package Finished_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Finished_Measurement);
   type Session is record
      Job : Files.Process_Jobs.Session;
      Target_Path : Ada.Strings.Unbounded.Unbounded_String;
      Targets : Path_Vectors.Vector;
      Done_Queue : Finished_Vectors.Vector;
   end record;
end Files.Folder_Size;
