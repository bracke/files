--  Test-only queries of Files.Folder_Size, kept out of the program.
package Files.Folder_Size.Testing is

   --  @param Scan A measurement session.
   --  @return The folder it measures, or "" when idle.
   function Target (Scan : Session) return String;

   --  @param Scan A measurement session.
   --  @return How many folders its running helper was given.
   function Batch_Length (Scan : Session) return Natural;

end Files.Folder_Size.Testing;
