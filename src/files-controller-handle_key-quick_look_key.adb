with Files.Model.Quick_Look;
separate (Files.Controller.Handle_Key)
--  Quick Look on top owns the keyboard: Space closes it (Escape, as for
--  every overlay, is Top_Overlay_Key's); the grid-navigation keys (arrows,
--  Home/End, Page Up/Down) move the selection underneath -- as they do in
--  the file grid, through the same results -- and re-preview the newly
--  selected item, so the user can flip through files without leaving
--  Quick Look. Every other key is swallowed.
procedure Quick_Look_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Modifiers /= Guikit.Input.No_Modifiers then
      return;
   end if;
   case Key is
      when Guikit.Input.Key_Space =>
         Files.Model.Quick_Look.Close (Model);
         Result := Successful_Command_Result (Files.Commands.Toggle_Quick_Look_Command);
         return;
      when Guikit.Input.Key_Up =>
         Result := Step_Selection_Result (Model, Guikit.Input.Move_Up);
      when Guikit.Input.Key_Down =>
         Result := Step_Selection_Result (Model, Guikit.Input.Move_Down);
      when Guikit.Input.Key_Left =>
         Result := Step_Selection_Result (Model, Guikit.Input.Move_Left);
      when Guikit.Input.Key_Right =>
         Result := Step_Selection_Result (Model, Guikit.Input.Move_Right);
      when Guikit.Input.Key_Home =>
         Result := First_Selection_Result (Model);
      when Guikit.Input.Key_End =>
         Result := Last_Selection_Result (Model);
      when Guikit.Input.Key_Page_Up =>
         Result := Page_Selection_Result (Model, Down => False);
      when Guikit.Input.Key_Page_Down =>
         Result := Page_Selection_Result (Model, Down => True);
      when others =>
         return;
   end case;
   if Result.Status = Controller_Selection_Moved then
      Files.Model.Quick_Look.Open
        (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selection.Selected_Item (Model)));
   end if;
end Quick_Look_Key;
