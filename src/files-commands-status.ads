with Files.Model;

--  Which commands can run in a window's state, and why not when one cannot:
--  the one set of enablement rules. Apart from Files.Commands, which names
--  the commands without knowing the model, so translating input does not
--  depend on it.
package Files.Commands.Status is

   --  Return whether a command is executable in the current model state and,
   --  when it is not, why. This is the one set of enablement rules: Is_Enabled
   --  and the controller's disabled-command report both read it.
   --
   --  @param Id Command identifier.
   --  @param Model Current window model.
   --  @return Enablement and the reason a disabled command cannot run.
   function Status_Of
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Command_Status;

   --  Return whether a command is executable in the current model state.
   --
   --  @param Id Command identifier.
   --  @param Model Current window model.
   --  @return True when command can execute (Status_Of (Id, Model).Enabled).
   function Is_Enabled
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Boolean;

   --  What the host offers, as the window layer sampled it into the model
   --  (Files.Model.Status_Samples.Set_Host), so a snapshot built on every
   --  change asks the host nothing. A window samples it before its first
   --  frame; a model no window sampled (a test, the helper process) takes
   --  the host to be able to, and the operation itself still refuses what
   --  the host cannot do.
   --
   --  @param Model Current window model.
   --  @return True when the host has a trash folder to go to.
   function Trash_Available (Model : Files.Model.Window_Model) return Boolean;

   --  @param Model Current window model.
   --  @return True when the host can edit permission bits.
   function Permissions_Supported (Model : Files.Model.Window_Model) return Boolean;

   --  @param Model Current window model.
   --  @return True when the host can edit owner and group.
   function Ownership_Supported (Model : Files.Model.Window_Model) return Boolean;

end Files.Commands.Status;
