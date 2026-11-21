with Hostkit;
with Hostkit.Spawn;

--  The helper processes files starts from its own program, and the flag that
--  says which one a process is. Launch sites and the dispatcher
--  (Files.Job_Drivers.Helpers) both spell a mode through Flag, so the two cannot
--  drift apart by a typo; every launch goes through Start_Helper.
package Files.Jobs.Helper_Modes is

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

   --  The mode a command-line flag starts, if it names one.
   --
   --  @param Argument A command-line argument.
   --  @param Found Set True when Argument is a helper flag.
   --  @return Its mode, when Found.
   function Mode_Of (Argument : String; Found : out Boolean) return Helper_Mode;

   --  Start a helper process: Program (this program when "") with Arguments,
   --  whose first is the helper's flag, and nothing inherited beyond the
   --  defaults.
   --
   --  @param Arguments The helper flag, then its own arguments.
   --  @param Child The started process, when this returns True.
   --  @param Program The program to start; "" for this one.
   --  @return True when the process started.
   function Start_Helper
     (Arguments : Hostkit.String_Vectors.Vector;
      Child     : out Hostkit.Spawn.Process_Handle;
      Program   : String := "") return Boolean;

end Files.Jobs.Helper_Modes;
