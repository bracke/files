--  Test-only queries of Files.Folder_Size.Measuring, kept out of the program.
package Files.Folder_Size.Measuring.Testing is

   --  @param Scan A measurement session.
   --  @return The folder it measures, or "" when idle.
   function Target (Scan : Session) return String;

   --  @param Scan A measurement session.
   --  @return How many folders its running helper was given.
   function Batch_Length (Scan : Session) return Natural;

   --  Make the next Count result reads fail as a result that will not open
   --  yet does (on Windows, a just-published file can refuse its lease).
   --  @param Count How many reads fail; 0 ends the fault.
   procedure Fail_Result_Reads (Count : Natural);

   --  @return How many folder-size helpers have started (launches that did
   --  not fail) since the program began; compare two readings.
   function Helper_Starts return Natural;

   --  @param Scan Measurements to inspect.
   --  @return True when a helper is active.
   function Is_Active (Scan : Session) return Boolean;

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

end Files.Folder_Size.Measuring.Testing;
