separate (Files.Controller.Handle_Key)
--  The Menu key, or Shift+F10 where a keyboard has none, opens the
--  context menu on the current selection -- the keyboard equivalent of a
--  right-click -- so its rows are reachable and navigable without a mouse.
procedure Menu_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if ((Key = Guikit.Input.Key_F10 and then Modifiers (Guikit.Input.Shift_Key))
       or else (Key = Guikit.Input.Key_Menu and then Modifiers = Guikit.Input.No_Modifiers))
     and then Files.Model.Focus (Model) = Files.Types.Focus_None
   then
      if Files.Model.Selected_Count (Model) > 0 then
         Files.Model.Open_Context_Menu
           (Model, 0, 0, Files.Model.Context_Menu_Item, Files.Model.Selected_Index (Model));
      else
         Files.Model.Open_Context_Menu (Model, 0, 0, Files.Model.Context_Menu_Empty);
      end if;
      Result := Make_Result (Controller_Selection_Moved);
      return;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Menu_Key;
