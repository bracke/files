separate (Files.Events.Translate_Click)
--  The toolbar (path, breadcrumbs, filter, scope chip) and the bottom bar.
procedure Toolbar_Click (Handled : out Boolean; Result : out Input_Action) is
begin
   Handled := True;
   if Path_Star.Visible
     and then Within (X, Path_Star.X, Path_Star.Width)
     and then Within (Y, Path_Star.Y, Path_Star.Height)
   then
      --  The path-bar favorite star takes precedence over the breadcrumb and
      --  path-input hit zones it sits inside: a click here toggles the
      --  current directory's favorite rather than focusing the path field.
      Result := (Kind => Path_Favorite_Toggle_Input_Action, others => <>);
      return;
   elsif Breadcrumb_Index /= 0 then
      Result := Breadcrumb_Action (Breadcrumb_Index);
      return;
   elsif Within (X, Toolbar.Middle_X, Toolbar.Middle_Width)
     and then Within (Y, Toolbar_Input_Y, Toolbar_Input_H)
   then
      Result :=
        Text_Click
          (Files.Types.Focus_Path_Input,
           Cursor_At
              (Text        => Snapshot.Path_Input_Text,
              Text_X      =>
                 Saturating_Add
                   (Saturating_Add
                      (Saturating_Add (Toolbar.Middle_X, Files.Rendering.Toolbar_Field_Margin),
                       Guikit.Layout.Input_Field_Padding),
                    Files.Rendering.Path_Bar_Content_Offset (Width, Line_Height)),
              Click_X     => X,
              Text_Width  =>
                (declare
                   Path_W : constant Natural :=
                     (if Toolbar.Middle_Width > 2 * Files.Rendering.Toolbar_Field_Margin
                      then Toolbar.Middle_Width - 2 * Files.Rendering.Toolbar_Field_Margin else 0);
                   Used   : constant Natural :=
                     2 * Guikit.Layout.Input_Field_Padding
                     + Files.Rendering.Path_Bar_Content_Offset (Width, Line_Height);
                 begin (if Path_W > Used then Path_W - Used else 0)),
              Focused     => Snapshot.Focus = Files.Types.Focus_Path_Input));
      return;
   elsif Scope_Chip.Visible
     and then Within (X, Scope_Chip.X, Scope_Chip.Width)
     and then Within (Y, Scope_Chip.Y, Scope_Chip.Height)
   then
      --  The scope chip sits inside the filter section and takes precedence
      --  over the filter input hit zone: a click here cycles the search scope
      --  rather than focusing the filter field.
      Result := (Kind => Search_Scope_Toggle_Input_Action, others => <>);
      return;
   elsif Within (X, Toolbar.Right_X, Toolbar.Right_Width)
     and then Within (Y, Toolbar_Input_Y, Toolbar_Input_H)
   then
      Result :=
        Text_Click
          (Files.Types.Focus_Filter_Input,
           Cursor_At
              (Text        => Snapshot.Filter_Text,
               Text_X      =>
                 Saturating_Add
                   (Saturating_Add (Toolbar.Right_X, Files.Rendering.Toolbar_Field_Margin),
                    Guikit.Layout.Input_Field_Padding),
               Click_X     => X,
               Text_Width  =>
                 (declare
                    Filter_W : constant Natural :=
                      Guikit.Layout.Filter_Input_Field_Width
                        (Toolbar, Files.UI.Filter_Scope_Chip_Width (Line_Height), Line_Height);
                  begin
                    (if Filter_W > 2 * Guikit.Layout.Input_Field_Padding
                     then Filter_W - 2 * Guikit.Layout.Input_Field_Padding else 0)),
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
      Result := Command_Action (Command, Activate);
      return;
   end if;
   Handled := False;
   Result := No_Action (Activate);
end Toolbar_Click;
