with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Files.File_System;

--  Incremental, non-blocking folder-size measurement.
--
--  The info pane shows the recursive size of the selected directory. Computing
--  it synchronously (Files.File_System.Directory_Size) walks the whole subtree
--  on the UI thread, so moving the selection between folders stalls while the
--  pane is open. This package spreads the same walk across many frames: the UI
--  posts a request for the selected directory, advances the walk a bounded
--  amount each frame (Step), and collects the finished measurement (Take) to
--  publish into the model. It is single-threaded; all operations run on the UI
--  thread. For a subtree that stays within the entry- and depth-guards the
--  result is identical to Files.File_System.Directory_Size.
package Files.Folder_Size is

   --  A set of directories to measure (absolute paths).
   package Path_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Ada.Strings.Unbounded.Unbounded_String,
      "="          => Ada.Strings.Unbounded."=");

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

   --  Advance the walk in progress by up to Budget directory entries. Does
   --  nothing when no measurement is active. When the subtree is exhausted the
   --  result becomes available to Take.
   --
   --  @param Budget Maximum number of directory entries to visit this call.
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

end Files.Folder_Size;
