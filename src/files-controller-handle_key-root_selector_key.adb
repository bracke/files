separate (Files.Controller.Handle_Key)
--  The command palette may intentionally be stacked above the root
--  selector.  In that state the palette remains the keyboard owner so
--  its general text-editing paths (Backspace, Delete, word deletion)
--  below are reachable; command execution is still constrained by the
--  root-selector allowlist in Execute_Command.
procedure Root_Selector_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Files.Model.Root_Selector_Is_Open (Model)
     and then not Files.Model.Command_Palette_Is_Open (Model)
   then
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Close_Root_Selector (Model);
         Result := Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         return;
      elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
         Result := Handle_Root_Click (Model, Settings, Files.Model.Root_Selected_Index (Model));
         return;
      elsif Key = Guikit.Input.Key_Left and then Modifiers = Guikit.Input.No_Modifiers then
         Result := Root_Selection_Result (Model, Guikit.Input.Move_Left);
         return;
      elsif Key = Guikit.Input.Key_Right and then Modifiers = Guikit.Input.No_Modifiers then
         Result := Root_Selection_Result (Model, Guikit.Input.Move_Right);
         return;
      elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
         Result := Root_Selection_Result (Model, Guikit.Input.Move_Up);
         return;
      elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
         Result := Root_Selection_Result (Model, Guikit.Input.Move_Down);
         return;
      elsif Key = Guikit.Input.Key_Home and then Modifiers = Guikit.Input.No_Modifiers then
         Result := Root_Jump_Result (Model, 1);
         return;
      elsif Key = Guikit.Input.Key_End and then Modifiers = Guikit.Input.No_Modifiers then
         Result := Root_Jump_Result (Model, Files.Model.Root_Count (Model));
         return;
      elsif Action.Kind = Files.Events.Command_Input_Action
        and then Action.Command = Files.Commands.Open_Command_Palette_Command
      then
         null;
      else
         Result := Make_Result (Controller_Ignored);
         return;
      end if;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Root_Selector_Key;
