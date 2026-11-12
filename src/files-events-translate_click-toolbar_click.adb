separate (Files.Events.Translate_Click)
--  The toolbar (path, breadcrumbs, filter, scope chip) and the bottom bar.
procedure Toolbar_Click (Handled : out Boolean; Result : out Input_Action) is
   Toolbar          : constant Guikit.Layout.Toolbar_Layout :=
     Guikit.Layout.Calculate_Toolbar_Layout (Width, Line_Height);
   Toolbar_Input_Y  : constant Natural := Guikit.Layout.Toolbar_Input_Y (Line_Height);
   Toolbar_Input_H  : constant Natural := Guikit.Layout.Toolbar_Input_Height (Line_Height);
   Scope_Chip       : constant Guikit.Layout.Scope_Chip_Region :=
     Guikit.Layout.Filter_Scope_Chip_Region_Of
       (Toolbar, Files.UI.Filter_Scope_Chip_Width (Line_Height), Line_Height);
   Path_Star        : constant Files.Rendering.Path_Favorite_Star_Bounds :=
     Files.Rendering.Path_Favorite_Star_Region (Width, Line_Height);
   Breadcrumb_Index : constant Natural :=
     Files.Rendering.Hit.Breadcrumb_At
       (Files.Rendering.Calculate_Breadcrumb_Layout (Snapshot, Width, Line_Height), X, Y);
   Path_Text        : constant Files.Rendering.Field_Text_Region :=
     Files.Rendering.Path_Field_Text_Region (Toolbar, Width, Line_Height);
   Filter_Text      : constant Files.Rendering.Field_Text_Region :=
     Files.Rendering.Filter_Field_Text_Region (Toolbar, Line_Height);
begin
   Handled := True;
   if Path_Star.Visible
     and then Within (X, Path_Star.X, Path_Star.Width)
     and then Within (Y, Path_Star.Y, Path_Star.Height)
   then
      --  The path-bar favorite star takes precedence over the breadcrumb and
      --  path-input hit zones it sits inside: a click here toggles the
      --  current directory's favorite rather than focusing the path field.
      Result := (Kind => Path_Favorite_Toggle_Input_Action);
      return;
   elsif Breadcrumb_Index /= 0 then
      Result := Breadcrumb_Action (Breadcrumb_Index);
      return;
   elsif Within (X, Path_Text.Field_X, Path_Text.Field_Width)
     and then Within (Y, Toolbar_Input_Y, Toolbar_Input_H)
   then
      Result :=
        Text_Click
          (Files.Types.Focus_Path_Input,
           Cursor_At
             (Text        => Snapshot.Path_Input_Text,
              Text_X      => Path_Text.X,
              Click_X     => X,
              Text_Width  => Path_Text.Width,
              Focused     => Snapshot.Focus = Files.Types.Focus_Path_Input));
      return;
   elsif Scope_Chip.Visible
     and then Within (X, Scope_Chip.X, Scope_Chip.Width)
     and then Within (Y, Scope_Chip.Y, Scope_Chip.Height)
   then
      --  The scope chip sits inside the filter section and takes precedence
      --  over the filter input hit zone: a click here cycles the search scope
      --  rather than focusing the filter field.
      Result := (Kind => Search_Scope_Toggle_Input_Action);
      return;
   elsif Within (X, Filter_Text.Field_X, Filter_Text.Field_Width)
     and then Within (Y, Toolbar_Input_Y, Toolbar_Input_H)
   then
      Result :=
        Text_Click
          (Files.Types.Focus_Filter_Input,
           Cursor_At
             (Text        => Snapshot.Filter_Text,
              Text_X      => Filter_Text.X,
              Click_X     => X,
              Text_Width  => Filter_Text.Width,
              Focused     => Snapshot.Focus = Files.Types.Focus_Filter_Input));
      return;
   end if;

   Command := Files.Rendering.Hit.Toolbar_Command_At (X, Y, Width, Line_Height);
   if Command = Files.Commands.No_Command then
      Command :=
        Files.Rendering.Hit.Bottom_Bar_Command_At
          (X, Y, Width, Height, Snapshot.Sort_Field,
           Files.Rendering.Free_Space_Label_Width (Snapshot, Line_Height), Line_Height);
   end if;

   if Command /= Files.Commands.No_Command then
      Result := Command_Action (Command);
      return;
   end if;
   Handled := False;
   Result := No_Action;
end Toolbar_Click;
