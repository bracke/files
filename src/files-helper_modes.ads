--  The helper processes files starts from its own program, and the flag that
--  says which one a process is. Launch sites and the dispatcher
--  (Files.Job_Helpers) both spell a mode through Flag, so the two cannot
--  drift apart by a typo.
package Files.Helper_Modes with Pure is

   type Helper_Mode is (Transfer, Operation, Refresh, Watch, Folder_Size, Scavenge, Cleanup);

   --  @param Mode A helper mode.
   --  @return The command-line flag that starts it.
   function Flag (Mode : Helper_Mode) return String is
     (case Mode is
         when Transfer    => "--files-transfer",
         when Operation   => "--files-operation",
         when Refresh     => "--files-refresh",
         when Watch       => "--files-watch",
         when Folder_Size => "--files-folder-size",
         when Scavenge    => "--files-scavenge",
         when Cleanup     => "--files-cleanup");

end Files.Helper_Modes;
