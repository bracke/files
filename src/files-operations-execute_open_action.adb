separate (Files.Operations)
   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Detach      : Boolean := False)
      return Boolean
   is
      Executable : constant String := To_String (Action.Executable);
      Arguments  : constant Hostkit.String_Vectors.Vector := Host_Arguments (Action.Arguments);
   begin
      Exit_Status := -1;

      if Executable = "" then
         return False;
      end if;

      --  An explicit-shell action is a command line, so it goes through the shell, and
      --  Hostkit quotes it for whichever shell that turns out to be. Detached, it is not
      --  waited for and has no exit status; awaited, its own status is reported.
      if Action.Use_Shell then
         if Hostkit.Shell.Executable = "" then
            return False;
         end if;

         return Hostkit.Process.Run_Shell_Command
                  (Hostkit.Shell.Command_Line (Executable, Arguments),
                   Wait        => not Detach,
                   Exit_Status => Exit_Status);
      end if;

      --  A detached launch starts the application and returns. It has no exit status to
      --  report and does not pretend to: what used to be reported was the backgrounding
      --  wrapper shell's zero, which said nothing about the application.
      if Detach then
         return Hostkit.Process.Launch (Executable, Arguments);
      end if;

      return Hostkit.Process.Run (Executable, Arguments, Exit_Status);
   exception
      when others =>
         Exit_Status := -1;
         return False;
   end Execute_Open_Action;
