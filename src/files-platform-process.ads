--  Child-process housekeeping for asynchronously launched applications.
--
--  An "Open" or "Open With" launch is fire-and-forget: the application is started
--  and files does not wait for it. On POSIX that leaves the finished child as a
--  zombie until someone collects its status, so they must be collected -- but
--  never by waiting, because a task blocked on a child that runs for hours would
--  keep files itself from exiting.
package Files.Platform.Process is

   --  Collect any children that have already finished. Returns at once whether or
   --  not there are any, and never waits for one that is still running.
   --
   --  A no-op where the host has no such thing to collect (Windows).
   procedure Reap_Finished_Children;

   --  Can this host run a *raw* command line -- the exact string a shell parses --
   --  rather than an argument vector?
   --
   --  True only on Windows, and only because there it is the sole way to get a
   --  command line to cmd intact. GNAT.OS_Lib.Spawn takes a vector, and the C
   --  runtime rebuilds a command line from it, re-quoting each argument and escaping
   --  the quotes we put there; cmd then applies its own rule, stripping the first and
   --  last quote when it sees more than two. A shell command line handed through an
   --  argument vector is therefore mangled twice before cmd ever parses it, and no
   --  amount of quoting on our side survives the round trip.
   --
   --  POSIX needs none of this: sh takes -c and the command as ordinary vector
   --  elements, and nothing rewrites them.
   function Supports_Raw_Command_Line return Boolean;

   --  Run Command verbatim as a process command line.
   --
   --  @param Command The raw command line, quoted as the shell expects to see it.
   --  @param Wait True to run it to completion, False to start it and return.
   --  @param Exit_Status The command's exit status when Wait, else -1.
   --  @return True when the process ran (or, when not waiting, started).
   function Run_Command_Line
     (Command     : String;
      Wait        : Boolean;
      Exit_Status : out Integer)
      return Boolean;

end Files.Platform.Process;
