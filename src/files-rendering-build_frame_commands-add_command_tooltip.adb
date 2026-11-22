separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Command_Tooltip
     (X       : Natural;
      Y       : Natural;
      Tip_W   : Natural;
      Tip_H   : Natural;
      Command : Files.Commands.Command_Id) is
   begin
      Add_Tooltip_Text (X, Y, Tip_W, Tip_H, Command_Tooltip_Text (Command));
   end Add_Command_Tooltip;
