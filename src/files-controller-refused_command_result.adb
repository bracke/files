separate (Files.Controller)
   function Refused_Command_Result
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model)
      return Controller_Result is
   begin
      --  An overlay that owns the window refuses quietly: the command is not
      --  disabled, only out of place there.
      if (Files.Model.Root_Selector_Is_Open (Model)
          and then not Files.Commands.Allowed_With_Root_Selector (Id))
        or else (Files.Model.Settings_Pane_Is_Open (Model)
                 and then not Files.Commands.Allowed_With_Settings_Pane (Id))
      then
         return Make_Result (Controller_Ignored, Id);
      end if;
      return Disabled_Command_Result (Id, Model);
   end Refused_Command_Result;
