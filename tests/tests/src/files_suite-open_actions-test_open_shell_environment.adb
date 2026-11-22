with Files.Operations.Opening;
with Files.Operation_Results;
with Files.Settings.Testing;
with Files.Settings.Open_Actions;
with Files_Suite.Support.Guards;
separate (Files_Suite.Open_Actions)
   procedure Test_Open_Shell_Environment (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      declare
         --  Restores what the test changes, on failure too.
         Environment : Files_Suite.Support.Guards.Environment_Guard;
      begin
         Files_Suite.Support.Guards.Save (Environment, "COMSPEC");
         Files_Suite.Support.Guards.Save (Environment, "SHELL");
         Ada.Environment_Variables.Clear ("COMSPEC");
         Ada.Environment_Variables.Set ("SHELL", "/bin/custom-sh");
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            --  The shell family follows the host, so a SHELL left over from
            --  MSYS2 or Cygwin does not switch Windows away from cmd.
            Files_Suite.Support.Assert_Equal
              (Hostkit.Shell.Executable,
               "cmd.exe",
               "Windows without COMSPEC falls back to cmd");
            Files_Suite.Support.Assert_Equal
              (Hostkit.Shell.Command_Option,
               "/C",
               "the cmd fallback uses the Windows command option");
         else
            Files_Suite.Support.Assert_Equal
              (Hostkit.Shell.Executable,
               "/bin/sh",
               "a command files quoted for sh runs under /bin/sh, whatever SHELL names");
            Files_Suite.Support.Assert_Equal
              (Hostkit.Shell.Command_Option,
               "-c",
               "SHELL fallback uses POSIX command option");
         end if;
         Ada.Environment_Variables.Set ("COMSPEC", "C:\Windows\System32\cmd.exe");
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            Files_Suite.Support.Assert_Equal
              (Hostkit.Shell.Executable,
               "C:\Windows\System32\cmd.exe",
               "explicit shell uses COMSPEC on Windows");
            Files_Suite.Support.Assert_Equal
              (Hostkit.Shell.Command_Option,
               "/C",
               "COMSPEC shell uses Windows command option");
         else
            --  COMSPEC is set on Linux machines that run Wine; it must not
            --  switch a POSIX host to cmd and its quoting.
            Files_Suite.Support.Assert_Equal
              (Hostkit.Shell.Executable,
               "/bin/sh",
               "a COMSPEC in a POSIX environment does not replace the POSIX shell");
            Files_Suite.Support.Assert_Equal
              (Hostkit.Shell.Command_Option,
               "-c",
               "a POSIX host keeps the POSIX command option");
         end if;
      end;

      declare
         --  Restores what the test changes, on failure too.
         Environment : Files_Suite.Support.Guards.Environment_Guard;
         Missing_Shell_Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Missing_Shell_Model    : Files.Model.Window_Model := Sample_Model;
         Missing_Shell_Action   : Files.Operation_Results.Operation_Result;
      begin
         Files_Suite.Support.Guards.Save (Environment, "COMSPEC");
         Files_Suite.Support.Guards.Save (Environment, "SHELL");
         --  The host decides which variable names the shell: COMSPEC on
         --  Windows, SHELL elsewhere. Point the host's own one at nothing.
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            Ada.Environment_Variables.Set ("COMSPEC", Join (Root, "missing-shell"));
         else
            Ada.Environment_Variables.Clear ("COMSPEC");
            Ada.Environment_Variables.Set ("SHELL", Join (Root, "missing-shell"));
         end if;
         Files.Settings.Testing.Add_Open_Action
           (Missing_Shell_Settings,
            "text/plain",
            Files.Settings.Open_Actions.Make_Action
              ("cd", Files.Settings.String_Vectors.Empty_Vector, Use_Shell => True));
         Files.Model.Selection.Select_Visible (Missing_Shell_Model, 1);
         Missing_Shell_Action := Files.Operations.Opening.Open_Selected (Missing_Shell_Model, Missing_Shell_Settings);
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            Files_Suite.Support.Assert_Equal
              (Missing_Shell_Action.Status,
               Files.Operation_Results.Operation_Failed,
               "explicit shell action fails preflight when shell executable is missing");
            Assert
              (not Missing_Shell_Action.Execution.Attempted,
               "missing shell executable is rejected before spawn");
            Assert
              (not Missing_Shell_Action.Execution.Executable_Found,
               "missing shell executable records failed executable lookup");
            Files_Suite.Support.Assert_Equal
              (To_String (Missing_Shell_Action.Error_Key),
               "error.open_action.executable_missing",
               "missing shell executable reports executable diagnostic");
         else
            --  A POSIX host runs the commands files quotes for sh under
            --  /bin/sh whatever SHELL names, so a SHELL that names nothing
            --  does not stop the action.
            Assert
              (Missing_Shell_Action.Execution.Attempted,
               "a SHELL that names nothing does not stop a POSIX shell action");
         end if;
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Missing_Shell_Model),
               "error.open_action.executable_missing",
               "missing shell executable records model diagnostic");
         end if;
      end;
   end Test_Open_Shell_Environment;
