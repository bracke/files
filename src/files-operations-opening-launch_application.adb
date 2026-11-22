with Hostkit.Process;

separate (Files.Operations.Opening)
function Launch_Application
  (Model   : in out Files.Model.Window_Model;
   App     : Files.Desktop_Applications.Application;
   Targets : Files.Types.String_Vectors.Vector)
   return Operation_Result
is
   --  An application that runs in a terminal (Terminal=true) is started
   --  inside the one Open Terminal would open.
   Actions : constant Files.Desktop_Applications.Open_Action_Vectors.Vector :=
     Files.Desktop_Applications.Launch_Actions
       (App, Targets, (if App.Terminal then Hostkit.Process.Default_Terminal else ""));
begin
   if Actions.Is_Empty then
      Files.Model.Set_Error (Model, "error.terminal.unavailable");
      return
        Make_Result
          (Operation_Failed,
           "error.terminal.unavailable",
           (if Targets.Is_Empty then "" else To_String (Targets.First_Element)));
   end if;
   return Launch_Open_Actions (Model, Actions, Targets);
end Launch_Application;
