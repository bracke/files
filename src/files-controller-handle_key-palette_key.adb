separate (Files.Controller.Handle_Key)
--  The command palette on top: Enter activates the highlighted command, the
--  arrows, Home, End and the page keys move the highlight. Other keys are
--  its query field's (Editing_Key), or the shortcuts the palette allows.
procedure Palette_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := Modifiers = Guikit.Input.No_Modifiers;
   Result := Make_Result (Controller_Palette_Updated);
   if not Handled then
      return;
   end if;
   --  The keys below act on the rows, which may come before the first
   --  frame since the palette opened.
   Files.Overlays.Command_Palette.Ensure_Listed (Model);
   case Key is
      when Guikit.Input.Key_Return =>
         Result := Commit_Focused_Text (Model, Settings, Modifiers);
      when Guikit.Input.Key_Left | Guikit.Input.Key_Up =>
         Files.Model.Command_Palette.Move_Selection (Model, -1);
      when Guikit.Input.Key_Right | Guikit.Input.Key_Down =>
         Files.Model.Command_Palette.Move_Selection (Model, 1);
      when Guikit.Input.Key_Home =>
         Files.Model.Command_Palette.Select_First (Model);
      when Guikit.Input.Key_End =>
         Files.Model.Command_Palette.Select_Last (Model);
      when Guikit.Input.Key_Page_Up =>
         Files.Model.Command_Palette.Page (Model, Down => False);
      when Guikit.Input.Key_Page_Down =>
         Files.Model.Command_Palette.Page (Model, Down => True);
      when others =>
         Handled := False;
         Result := Make_Result (Controller_Ignored);
   end case;
end Palette_Key;
