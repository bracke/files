--  The job subsystem below the file system: the helper processes files
--  starts for long work, their transports and records, the per-process job
--  context and batch journal, the transfer job, and the scavenger that
--  recovers what a stopped helper left behind. Nothing here knows the window
--  model: the jobs that drive a window's operations are Files.Job_Drivers,
--  and the background listing is Files.Refresh.
package Files.Jobs with Pure is
end Files.Jobs;
