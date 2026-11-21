separate (Files.Controller.Handle_Key)
--  The root selector on top: Enter opens the highlighted root, the arrows,
--  Home and End move the highlight, and every other key is consumed --
--  except the palette's shortcut, which may open the palette over it.
procedure Root_Selector_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Modifiers = Guikit.Input.No_Modifiers then
      case Key is
         when Guikit.Input.Key_Return =>
            Result := Handle_Root_Click (Model, Settings, Files.Model.Root_Selector.Selected_Index (Model));
         when others =>
            Result := Root_Highlight_Result (Model, Files.Input_Actions.Grid_Navigation_Of (Key));
      end case;
   elsif Action.Kind = Files.Input_Actions.Command_Input_Action
     and then Action.Command = Files.Commands.Open_Command_Palette_Command
   then
      Handled := False;
   end if;
end Root_Selector_Key;
