with Files.Quick_Look.Preparation;
with Files.Model.Quick_Look;
separate (Files.Controller.Handle_Key)
--  Quick Look on top owns the keyboard: Space closes it (Escape, as for
--  every overlay, is Top_Overlay_Key's); the grid-navigation keys (arrows,
--  Home/End, Page Up/Down) move the selection underneath -- as they do in
--  the file grid, through the same results -- and re-preview the newly
--  selected item, so the user can flip through files without leaving
--  Quick Look. Every other key is swallowed.
procedure Quick_Look_Key (Handled : out Boolean; Result : out Controller_Result) is
   Navigation : constant Files.Input_Actions.Grid_Navigation := Files.Input_Actions.Grid_Navigation_Of (Key);
begin
   Handled := True;
   Result := Make_Result (Controller_Ignored);
   if Modifiers /= Guikit.Input.No_Modifiers then
      return;
   elsif Key = Guikit.Input.Key_Space then
      Files.Model.Quick_Look.Close (Model);
      Result := Successful_Command_Result (Files.Commands.Toggle_Quick_Look_Command);
   elsif Navigation.Move /= Files.Input_Actions.No_Grid_Move then
      Result := Selection_Result (Model, Navigation);
      if Result.Status = Controller_Selection_Moved then
         Files.Model.Quick_Look.Open
           (Model, Files.Quick_Look.Preparation.Prepare (Files.Model.Selection.Selected_Item (Model)));
      end if;
   end if;
end Quick_Look_Key;
