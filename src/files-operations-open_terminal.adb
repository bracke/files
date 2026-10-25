separate (Files.Operations)
function Open_Terminal
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   pragma Unreferenced (Settings);
   Directory : constant String := Files.Model.Current_Path (Model);
   Terminal  : constant String := Detected_Terminal;
begin
   if Directory = ""
     or else Files.Model.In_Recent_View (Model)
     or else Files.File_System.Is_Trash_Files_Directory (Directory)
   then
      return Disabled (Model, "error.terminal.unavailable");
   elsif Terminal = "" then
      Files.Model.Set_Error (Model, "error.terminal.unavailable");
      return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
   end if;

   declare
      --  Most terminals take their working directory from whoever starts
      --  them, so the command changes into the viewed directory first. Two
      --  do not, and both would silently open somewhere else instead.
      --  A command line for a terminal that has to be told the directory,
      --  quoted by Hostkit for whichever shell will read it back.
      function Launch_Command
        (Program   : String;
         Options   : Hostkit.String_Vectors.Vector;
         Directory : String)
         return String
      is
         Arguments : Hostkit.String_Vectors.Vector;
      begin
         for Option of Options loop
            Arguments.Append (Option);
         end loop;

         Arguments.Append (To_Unbounded_String (Directory));
         return Hostkit.Shell.Command_Line (Program, Arguments);
      end Launch_Command;

      function Terminal_Command return String is
         Open_Options : constant Hostkit.String_Vectors.Vector :=
           [To_Unbounded_String ("-a"), To_Unbounded_String ("Terminal")];
         Wt_Options   : constant Hostkit.String_Vectors.Vector :=
           [To_Unbounded_String ("-d")];
      begin
         case Hostkit.Host.Current is
            when Hostkit.Host.MacOS =>
               --  A macOS terminal is an application bundle: `open` hands it
               --  the directory, which Terminal.app opens a window in. It has
               --  no working directory of its own to inherit.
               if Terminal = "open" then
                  return Launch_Command ("open", Open_Options, Directory);
               end if;

            when Hostkit.Host.Windows =>
               --  Windows Terminal ignores the cwd it was started in and uses
               --  the starting directory configured in its profile -- usually
               --  the user's home. -d is how it is told otherwise.
               if Terminal = "wt" then
                  return Launch_Command ("wt", Wt_Options, Directory);
               end if;

            when Hostkit.Host.Linux | Hostkit.Host.Unsupported =>
               null;
         end case;

         --  "cd /d" on cmd, because plain cd will not cross to another drive.
         return
           (if Hostkit.Shell.Is_Command_Shell then "cd /d " else "cd ")
           & Hostkit.Shell.Quote (Directory)
           & " && " & Hostkit.Shell.Quote (Terminal);
      end Terminal_Command;

      Command : constant String := Terminal_Command;

      Exit_Status : Integer := -1;
      Started     : Boolean;
   begin
      if Hostkit.Shell.Executable = "" then
         Files.Model.Set_Error (Model, "error.terminal.unavailable");
         return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
      end if;

      --  Detached: the terminal outlives us and is not waited for. This used to end
      --  in "</dev/null >/dev/null 2>&1 &", a shell asked to background the process
      --  because the spawn underneath blocked -- and a Windows shell cannot read a
      --  word of it.
      Started := Hostkit.Process.Run_Shell_Command (Command, Wait => False, Exit_Status => Exit_Status);

      if not Started then
         Files.Model.Set_Error (Model, "error.terminal.unavailable");
         return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Directory);
   end;
exception
   when others =>
      Files.Model.Set_Error (Model, "error.terminal.unavailable");
      return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
end Open_Terminal;
