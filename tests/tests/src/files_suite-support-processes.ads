--  What the suite asks of other processes it started.
package Files_Suite.Support.Processes is

   --  The scheduler state of a process, from the third field of Linux's
   --  /proc/<pid>/stat: 'R' running, 'S' sleeping, 'T' stopped, 'Z' a zombie
   --  nobody has reaped, and so on.
   --
   --  @param Process_Id Process to look at.
   --  @return Its state letter, or ' ' when there is no such process (or no
   --  /proc to ask).
   function Process_State (Process_Id : Integer) return Character;

end Files_Suite.Support.Processes;
