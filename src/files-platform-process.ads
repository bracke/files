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

end Files.Platform.Process;
