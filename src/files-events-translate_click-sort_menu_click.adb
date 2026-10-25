separate (Files.Events.Translate_Click)
--  The open sort menu: a row picks the sort, a click outside closes it.
procedure Sort_Menu_Click (Handled : out Boolean; Result : out Input_Action) is
begin
   Handled := True;
   --  The open sort menu owns pointer input just as it owns the keyboard.
   --  A click outside dismisses it without activating a toolbar, grid, or
   --  bottom-bar control behind the transient menu.
   if Snapshot.Sort_Menu_Open then
      Command :=
        Files.UI.Bottom_Bar_Sort_Menu_Command_At
          (X, Y, Width, Height, Snapshot.Sort_Field, Line_Height);
      if Command /= Files.Commands.No_Command then
         Result := Command_Action (Command, Activate);
         return;
      elsif Files.UI.Bottom_Bar_Sort_Menu_Contains
              (X, Y, Width, Height, Snapshot.Sort_Field, Line_Height)
      then
         --  Padding inside the menu is inert and must not fall through.
         Result := No_Action (Activate);
         return;
      else
         Result := Command_Action (Files.Commands.Close_Command_Palette_Command, Activate);
         return;
      end if;
   end if;
   Handled := False;
   Result := No_Action (Activate);
end Sort_Menu_Click;
