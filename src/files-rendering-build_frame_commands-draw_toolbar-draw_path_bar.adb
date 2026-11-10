separate (Files.Rendering.Build_Frame_Commands.Draw_Toolbar)
   --  The path field: its breadcrumbs or the text typed in it.
   procedure Draw_Path_Bar is
   begin
      declare
         Field_Margin : constant Natural := Toolbar_Field_Margin;
         Path_X : constant Natural :=
           Saturating_Add (Toolbar.Middle_X, Field_Margin);
         Path_W : constant Natural :=
           (if Toolbar.Middle_Width > Saturating_Multiply (Field_Margin, 2)
            then Toolbar.Middle_Width - Saturating_Multiply (Field_Margin, 2)
            else 0);
         Star         : constant Path_Favorite_Star_Bounds :=
           Path_Favorite_Star_Region (Width, Line_Height);
         Star_Reserve : constant Natural := Path_Bar_Content_Offset (Width, Line_Height);
         Text_Start   : constant Natural :=
           Saturating_Add (Saturating_Add (Path_X, Files.UI.Field_Padding (Line_Height)), Star_Reserve);
         Path_Text_W  : constant Natural :=
           (if Path_W > 2 * Files.UI.Field_Padding (Line_Height) + Star_Reserve
            then Path_W - 2 * Files.UI.Field_Padding (Line_Height) - Star_Reserve
            else 0);
         Path_Raw     : constant String := To_String (Snapshot.Path_Input_Text);
         --  While focused, start the text far enough in that the caret shows.
         Path_Skip    : constant Natural :=
           (if Snapshot.Focus = Files.Types.Focus_Path_Input
            then Files.UTF8.Byte_Offset_For_Display_Column
                   (Path_Raw,
                    Input_Scroll_Columns
                      (Path_Raw, Snapshot.Text_Cursor_Position, Path_Text_W, Line_Height))
            else 0);
         Path_Shown   : constant UString :=
           To_Unbounded_String (Path_Raw (Path_Raw'First + Natural'Min (Path_Skip, Path_Raw'Length) .. Path_Raw'Last));
      begin
         Add_Input_Field
           (Path_X,
            Toolbar_Input_Y,
            Path_W,
            Toolbar_Input_H,
            (if Snapshot.Path_Input_Valid then Input_Color else Input_Error_Color),
            Border_Color);
         --  Favorite toggle: a filled star when the current directory is a
         --  favorite, an empty star when not, drawn at the left of the path bar
         --  ahead of the breadcrumbs/edit field in both modes.
         if Star.Visible then
            declare
               Star_Hovered : constant Boolean :=
                 Has_Hover
                 and then Contains_Point (Star.X, Star.Y, Star.Width, Star.Height, Hover_X, Hover_Y);
            begin
               declare
                  Center_X : constant Float := Float (Star.X) + Float (Star.Width) / 2.0;
                  Center_Y : constant Float := Float (Star.Y) + Float (Star.Height) / 2.0;
                  --  A five-pointed star spans ~1.9 * Radius across and ~1.81 *
                  --  Radius tall; size the radius to fill the box with a margin.
                  Radius   : constant Float :=
                    0.82 * Float'Min (Float (Star.Width) / 1.9, Float (Star.Height) / 1.81);
                  Stroke   : constant Float := Float'Max (1.5, Float (Line_Height) / 10.0);
               begin
                  --  Draw the favourite indicator as a vector shape (a filled
                  --  star when favourited, an outline star when not) so it fills
                  --  its box crisply at any size, unlike the small font glyph.
                  if Snapshot.Current_Path_Is_Favorite then
                     Add_Star_Fill (Center_X, Center_Y, Radius, Accent_Gold_Color);
                  else
                     Add_Star_Outline (Center_X, Center_Y, Radius, Stroke, Muted_Text_Color);
                  end if;
               end;
               if Star_Hovered then
                  Add_Border (Star.X, Star.Y, Star.Width, Star.Height, Hover_Color);
               end if;
               Add_Accessibility_Node
                 (Role_Button,
                  Star.X,
                  Star.Y,
                  Star.Width,
                  Star.Height,
                  Localized
                    (if Snapshot.Current_Path_Is_Favorite
                     then "accessibility.favorite_toggle.on"
                     else "accessibility.favorite_toggle.off"),
                  Snapshot.Current_Path,
                  Enabled  => True,
                  Selected => Snapshot.Current_Path_Is_Favorite);
            end;
         end if;
         if Snapshot.Focus = Files.Types.Focus_Path_Input
           or else Breadcrumb_Rows.Is_Empty
         then
            Add_Text
              (Text_Start,
               Toolbar_Input_Text_Y,
               Path_Text_W,
               Toolbar_Input_Text_H,
               Path_Shown,
               Fit => True);
         else
            for I in 1 .. Natural (Breadcrumb_Rows.Length) loop
               declare
                  Seg     : constant Breadcrumb_Segment_Layout :=
                    Breadcrumb_Rows.Element (Positive (I));
                  Is_Last : constant Boolean := I = Natural (Breadcrumb_Rows.Length);
                  Advance : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
                  Label   : constant UString :=
                    (if Seg.Clickable and then Seg.Segment_Index /= 0
                     then Snapshot.Breadcrumb_Segments.Element (Positive (Seg.Segment_Index)).Label
                     else To_Unbounded_String (Files.Breadcrumbs.Ellipsis_Label));
                  Hovered : constant Boolean :=
                    Seg.Clickable
                    and then Has_Hover
                    and then Contains_Point (Seg.X, Seg.Y, Seg.Width, Seg.Height, Hover_X, Hover_Y);
               begin
                  Add_Text
                    (Seg.X,
                     Toolbar_Input_Text_Y,
                     Seg.Width,
                     Toolbar_Input_Text_H,
                     Label,
                     Color => (if Seg.Clickable then Text_Color else Muted_Text_Color),
                     Fit   => True);
                  if Hovered then
                     Add_Border (Seg.X, Seg.Y, Seg.Width, Seg.Height, Hover_Color);
                  end if;
                  if Seg.Clickable and then Seg.Segment_Index /= 0 then
                     Add_Accessibility_Node
                       (Role_Button,
                        Seg.X,
                        Seg.Y,
                        Seg.Width,
                        Seg.Height,
                        Label,
                        Snapshot.Breadcrumb_Segments.Element (Positive (Seg.Segment_Index)).Ancestor_Path);
                  end if;
                  if not Is_Last then
                     --  Draw '>' in the middle of the three separator cells so
                     --  it has a full character width of space on each side.
                     Add_Text
                       (Saturating_Add (Saturating_Add (Seg.X, Seg.Width), Advance),
                        Toolbar_Input_Text_Y,
                        Advance,
                        Toolbar_Input_Text_H,
                        To_Unbounded_String (Breadcrumb_Separator_Text),
                        Color => Muted_Text_Color);
                  end if;
               end;
            end loop;
         end if;
         if Snapshot.Focus = Files.Types.Focus_Path_Input or else not Snapshot.Path_Input_Valid then
            Add_Border
              (Path_X,
               Toolbar_Input_Y,
               Path_W,
               Toolbar_Input_H,
               (if Snapshot.Path_Input_Valid then Border_Color else Input_Error_Color));
         elsif Has_Hover
           and then Contains_Point
             (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Hover_X, Hover_Y)
         then
            Add_Border (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Hover_Color);
         end if;
         if Is_Pressed (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H) then
            Add_Border (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Pressed_Color);
         end if;
         if Snapshot.Focus = Files.Types.Focus_Path_Input then
            Add_Focus_Ring (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H);
            Add_Caret
              (Saturating_Add (Path_X, Star_Reserve),
               Toolbar_Input_Y,
               (if Path_W > Star_Reserve then Path_W - Star_Reserve else 0),
               Toolbar_Input_H,
               Path_Shown,
               (if Snapshot.Text_Cursor_Position > Path_Skip
                then Snapshot.Text_Cursor_Position - Path_Skip else 0));
         end if;
      end;
      Add_Command_Tooltip
        (Toolbar.Middle_X,
         Toolbar_Input_Y,
         Toolbar.Middle_Width,
         Toolbar_Input_H,
         Files.Commands.Focus_Path_Input_Command);
      Add_Accessibility_Node
        (Role_Text_Input,
         Toolbar.Middle_X,
         Toolbar_Input_Y,
         Toolbar.Middle_Width,
         Toolbar_Input_H,
         Localized (Files.Commands.Name_Key (Files.Commands.Focus_Path_Input_Command)),
         Path_Input_Accessible_Description,
         Enabled => True,
         Focused => Snapshot.Focus = Files.Types.Focus_Path_Input);
   end Draw_Path_Bar;
