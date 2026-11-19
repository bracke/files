--  Keeping a window's folder current: the background refresh it is
--  running, the native watch helper's change reports, and the timed re-read
--  that covers what the helper cannot see, paced so a burst of writes costs
--  one reload.
private package Files.Application.Windows.Watch is

   --  One pass of a window's folder watch: advance its refresh, drain the
   --  watch helper and re-read the folder when it changed or a poll is due.
   --  A window that is closing releases its jobs instead.
   --
   --  @param Runtime Window whose folder is watched.
   procedure Poll (Runtime : in out Runtime_Window);

end Files.Application.Windows.Watch;
