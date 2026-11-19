separate (Files.Operations)
function Open_Terminal
  (Model : in out Files.Model.Window_Model)
   return Operation_Result
is
   Directory : constant String := Files.Model.Current_Path (Model);
   Terminal  : constant String := Detected_Terminal;
begin
   if Directory = ""
     or else Files.Model.In_Recent_View (Model)
     or else Files.File_System.Trash.Is_Trash_Files_Directory (Directory)
   then
      return Disabled (Model, "error.terminal.unavailable");
   elsif Terminal = "" then
      Files.Model.Set_Error (Model, "error.terminal.unavailable");
      return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
   end if;

   declare
      --  Most terminals start where they are started; Hostkit tells the two
      --  that do not where to open.
      Command : constant String := Hostkit.Process.Terminal_Command (Terminal, Directory);

      Exit_Status : Integer := -1;
      Started     : Boolean;
   begin
      if Hostkit.Shell.Executable = "" then
         Files.Model.Set_Error (Model, "error.terminal.unavailable");
         return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
      end if;

      --  Detached: the terminal outlives us and is not waited for. The spawn
      --  itself detaches, so the command carries no shell backgrounding syntax
      --  and reads the same to every host's shell.
      Started := Hostkit.Process.Run_Shell_Command (Command, Wait => False, Exit_Status => Exit_Status);

      if not Started then
         Files.Model.Set_Error (Model, "error.terminal.unavailable");
         return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Directory);
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      Files.Model.Set_Error (Model, "error.terminal.unavailable");
      return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
end Open_Terminal;
