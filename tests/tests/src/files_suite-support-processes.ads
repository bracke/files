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

   --  When a process started, from the 22nd field of Linux's
   --  /proc/<pid>/stat (clock ticks since boot): with its id, what tells
   --  one process from a later one given the same id.
   --
   --  @param Process_Id Process to look at.
   --  @return Its start time as written there, or "" when there is no such
   --  process (or no /proc to ask).
   function Start_Time (Process_Id : Integer) return String;

   --  Process_State of the process that started at Started: ' ' once that
   --  one is gone, even when its id has been given to another since.
   --
   --  @param Process_Id Process to look at.
   --  @param Started Its Start_Time, taken while it ran.
   --  @return Its state letter, or ' ' when it is gone.
   function Process_State (Process_Id : Integer; Started : String) return Character;

end Files_Suite.Support.Processes;
