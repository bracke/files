--  The jobs that drive a window's work on helpers: an operation started from
--  the window and the helper side that runs it (Operation), the paste the
--  window advances in the foreground (Foreground), and the helper process
--  entry that dispatches every helper mode (Helpers). They sit above
--  Files.Operations, which they run; the job machinery they build on is
--  Files.Jobs, below the file system.
package Files.Job_Drivers with Pure is
end Files.Job_Drivers;
