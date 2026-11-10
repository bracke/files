--  Test-only queries of Files.Folder_Size, kept out of the program.
package Files.Folder_Size.Testing is

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

end Files.Folder_Size.Testing;
