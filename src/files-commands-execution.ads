with Files.Model;

--  Running a pure command: one whose whole effect is window-model state.
package Files.Commands.Execution is

   --  Run a pure model command: one whose whole effect is window-model state.
   --  Only the controller's Run_Command calls this, after the command entry
   --  has checked Is_Enabled; every other command is executed there.
   --
   --  @param Id Pure command identifier.
   --  @param Model Window model to mutate.
   procedure Execute
     (Id    : Pure_Command_Id;
      Model : in out Files.Model.Window_Model);

end Files.Commands.Execution;
