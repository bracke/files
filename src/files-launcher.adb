with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files.Platform.Process;

package body Files.Launcher is
   use Ada.Strings.Unbounded;
   use type GNAT.OS_Lib.Argument_List_Access;
   use type GNAT.OS_Lib.Process_Id;

   --  Collecting finished children is housekeeping, so it happens off the caller's
   --  thread rather than in the middle of an open.
   --
   --  It never waits for a child. A task that blocked on one would keep files from
   --  exiting -- the environment task waits for library-level tasks to finish, so
   --  quitting the file manager while the editor you opened is still running would
   --  hang on quit, which is the bug this whole change exists to remove. It only
   --  collects children that have *already* finished, which returns at once.
   --
   --  The terminate alternative is what makes that guarantee: when no one can call
   --  Note_Launch again, the task ends and the program is free to exit.
   task Reaper is
      entry Note_Launch;
   end Reaper;

   task body Reaper is
   begin
      loop
         select
            accept Note_Launch;
         or
            terminate;
         end select;

         Files.Platform.Process.Reap_Finished_Children;
      end loop;
   end Reaper;

   function Launch (Action : Files.Settings.Open_Action) return Boolean is
      Executable : constant String := To_String (Action.Executable);
      Count      : constant Natural := Natural (Action.Arguments.Length);
      Arguments  : GNAT.OS_Lib.Argument_List_Access :=
        new GNAT.OS_Lib.Argument_List (1 .. Count);
      Started    : GNAT.OS_Lib.Process_Id;
   begin
      if Executable = "" then
         GNAT.OS_Lib.Free (Arguments);
         return False;
      end if;

      for Index in 1 .. Count loop
         Arguments (Index) :=
           new String'(To_String (Action.Arguments.Element (Positive (Index))));
      end loop;

      --  Starts the process and returns without waiting for it.
      Started := GNAT.OS_Lib.Non_Blocking_Spawn (Executable, Arguments.all);
      GNAT.OS_Lib.Free (Arguments);

      if Started = GNAT.OS_Lib.Invalid_Pid then
         return False;
      end if;

      Reaper.Note_Launch;
      return True;
   exception
      when others =>
         if Arguments /= null then
            GNAT.OS_Lib.Free (Arguments);
         end if;
         return False;
   end Launch;

end Files.Launcher;
