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

   --  Set_Targets with the one directory Path.
   --
   --  @param Scan The window's scan.
   --  @param Path Absolute path of the directory to measure.
   procedure Request (Scan : in out Session; Path : String);

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
