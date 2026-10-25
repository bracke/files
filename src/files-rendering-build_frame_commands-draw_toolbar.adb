separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Toolbar is
   begin
      Result.Layout := Layout;
      Result.Theme_Palette := Snapshot.Theme_Palette;

      Add_Rect (0, 0, Width, Height, Canvas_Color);
      Add_Rect (0, 0, Width, Layout.Toolbar_Height, Toolbar_Color);
      Add_Rect (Layout.Main_X, Layout.Main_Y, Layout.Main_Width, Layout.Main_Height, Main_Color);
      Add_Rect (0, Bottom_Y, Width, Layout.Bottom_Bar_Height, Bottom_Bar_Color);
      if Layout.Toolbar_Height > 0 then
         Add_Rect (0, Layout.Toolbar_Height - 1, Width, 1, Border_Color);
      end if;
      Add_Rect (0, Bottom_Y, Width, 1, Border_Color);
      Add_Accessibility_Node
        (Role_Window,
         0,
         0,
         Width,
         Height,
         Snapshot.Current_Path);
      Add_Accessibility_Node
        (Role_Toolbar,
         0,
         0,
         Width,
         Layout.Toolbar_Height,
         Localized ("accessibility.toolbar"));
      Add_Accessibility_Node
        ((if Snapshot.View_Mode = Files.Types.Details then Role_Table else Role_List),
         Layout.Main_X,
         Layout.Main_Y,
         Layout.Main_Width,
         Layout.Main_Height,
         Localized ("accessibility.main_view"),
         Main_View_Accessible_Description);

      if Layout.Info_Pane_Width > 0 then
         Add_Rect
           (Layout.Main_Width,
            Layout.Main_Y,
            Layout.Info_Pane_Width,
            Layout.Main_Height,
            Pane_Color);
         Add_Rect
           (Layout.Main_Width,
            Layout.Main_Y,
            1,
            Layout.Main_Height,
            Border_Color);
      end if;

      for Button_Index in Toolbar_Button_Index loop
         declare
            Button_X : constant Natural := Guikit.Layout.Toolbar_Left_Button_X (Toolbar, Button_Index);
            Button_W : constant Natural := Guikit.Layout.Toolbar_Left_Button_Width (Toolbar, Button_Index);
            Command  : constant Files.Commands.Registered_Command_Id := Toolbar_Button_Commands (Button_Index);
            Button_Y : constant Natural := Toolbar_Input_Y;
            Button_H : constant Natural :=
              (if Button_Y >= Layout.Toolbar_Height
               then 0
               else Natural'Min (Toolbar_Input_H, Layout.Toolbar_Height - Button_Y));
            --  Per-button visual padding so the icons get breathing room and
            --  groups read separately. Inner padding for normal spacing; the
            --  end-of-group cell on either side of the navigation/file-action
            --  boundary gets a wider pad so the gap is visible.
            --  Slim vertical inset so the icon can occupy more of the button
            --  height (a modestly larger glyph) while staying inside the rect.
            Pad_V        : constant Natural :=
              Natural'Min (2, Button_H / 8);
            Inner_Pad    : constant Natural := Natural'Min (3, Button_W / 6);
            Group_Pad    : constant Natural := Natural'Min (8, Button_W / 4);
            Button_Pad_L : constant Natural :=
              (if Button_Index = First_File_Action_Button then Group_Pad else Inner_Pad);
            Button_Pad_R : constant Natural :=
              (if Button_Index = First_File_Action_Button - 1 then Group_Pad else Inner_Pad);
            Visible_X : constant Natural := Saturating_Add (Button_X, Button_Pad_L);
            Visible_W : constant Natural :=
              (if Button_W > Saturating_Add (Button_Pad_L, Button_Pad_R)
               then Button_W - Button_Pad_L - Button_Pad_R
               else 0);
            Visible_Y : constant Natural := Saturating_Add (Button_Y, Pad_V);
            Visible_H : constant Natural :=
              (if Button_H > Saturating_Multiply (Pad_V, 2)
               then Button_H - Saturating_Multiply (Pad_V, 2)
               else 0);
            Icon_Size : constant Natural :=
              (if Visible_W >= Guikit.Layout.Toolbar_Button_Width - 4
               then Natural'Min (Visible_H, Guikit.Layout.Toolbar_Button_Width - 8)
               else Natural'Min (Visible_W, Visible_H));
            Icon_X   : constant Natural :=
              (if Visible_W > Icon_Size then Visible_X + (Visible_W - Icon_Size) / 2 else Visible_X);
            Icon_Y   : constant Natural :=
              (if Visible_H > Icon_Size then Visible_Y + (Visible_H - Icon_Size) / 2 else Visible_Y);
            Enabled  : constant Boolean := Snapshot.Command_Enabled (Command);
            Hovered  : constant Boolean :=
              Has_Hover and then Contains_Point (Button_X, Button_Y, Button_W, Button_H, Hover_X, Hover_Y);
            Pressed  : constant Boolean := Is_Pressed (Button_X, Button_Y, Button_W, Button_H);
         begin
            if Visible_W > 0 and then Visible_H > 0 then
               --  Disabled buttons render with no fill and no border, exactly
               --  like an enabled idle button; only the icon dimming differs.
               if Pressed then
                  Add_Rect (Visible_X, Visible_Y, Visible_W, Visible_H, Pressed_Color);
                  Add_Border (Visible_X, Visible_Y, Visible_W, Visible_H, Border_Color);
               elsif Hovered then
                  Add_Rect (Visible_X, Visible_Y, Visible_W, Visible_H, Hover_Color);
                  Add_Border (Visible_X, Visible_Y, Visible_W, Visible_H, Border_Color);
               end if;
            end if;
            if Command = Files.Commands.Select_Drive_Command then
               Add_Toolbar_Drive_Icon (Icon_X, Icon_Y, Icon_Size, Enabled);
            else
               Add_Toolbar_Asset_Icon (Command, Icon_X, Icon_Y, Icon_Size, Enabled);
            end if;
            Add_Command_Tooltip
              (Button_X,
               Button_Y,
               Button_W,
               Button_H,
               Command);
            Add_Accessibility_Node
              (Role_Button,
               Button_X,
               Button_Y,
               Button_W,
               Button_H,
               Command_Label (Command),
               Localized (Files.Commands.Description_Key (Command)),
               Enabled => Enabled);
         end;
      end loop;

      --  Vertical divider between navigation group (drives/home/back/forward)
      --  and file-action group (create/delete) so the two groups read as
      --  distinct sets of controls.
      if Layout.Toolbar_Height > 0 then
         declare
            Group_Boundary_X : constant Natural :=
              Guikit.Layout.Toolbar_Left_Button_X (Toolbar, First_File_Action_Button);
            Divider_H : constant Natural :=
              Natural'Max (1, Layout.Toolbar_Height / 3);
            Divider_Y : constant Natural :=
              (if Layout.Toolbar_Height > Divider_H
               then (Layout.Toolbar_Height - Divider_H) / 2
               else 0);
         begin
            if Group_Boundary_X > 0
              and then Group_Boundary_X < Toolbar.Middle_X
            then
               Add_Rect (Group_Boundary_X, Divider_Y, 1, Divider_H, Border_Color);
            end if;
         end;
      end if;

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
           Saturating_Add (Saturating_Add (Path_X, Guikit.Layout.Input_Field_Padding), Star_Reserve);
         Path_Text_W  : constant Natural :=
           (if Path_W > 2 * Guikit.Layout.Input_Field_Padding + Star_Reserve
            then Path_W - 2 * Guikit.Layout.Input_Field_Padding - Star_Reserve
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
                     Add_Star_Fill (Center_X, Center_Y, Radius, Favorite_Star_Color);
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
      declare
         Field_Margin : constant Natural := Toolbar_Field_Margin;
         Filter_X : constant Natural :=
           Saturating_Add (Toolbar.Right_X, Field_Margin);
         --  The chip is sized to its localized label so it never abbreviates;
         --  the filter field is narrowed to end before it (when it fits).
         Scope_Chip_W : constant Natural := Files.UI.Filter_Scope_Chip_Width (Line_Height);
         Filter_W : constant Natural :=
           Guikit.Layout.Filter_Input_Field_Width (Toolbar, Scope_Chip_W, Line_Height);
         Scope_Chip : constant Guikit.Layout.Scope_Chip_Region :=
           Guikit.Layout.Filter_Scope_Chip_Region_Of (Toolbar, Scope_Chip_W, Line_Height);
         Filter_Text_W : constant Natural :=
           (if Filter_W > 2 * Guikit.Layout.Input_Field_Padding
            then Filter_W - 2 * Guikit.Layout.Input_Field_Padding
            else 0);
         Filter_Raw    : constant String := To_String (Snapshot.Filter_Text);
         Filter_Skip   : constant Natural :=
           (if Snapshot.Focus = Files.Types.Focus_Filter_Input
            then Files.UTF8.Byte_Offset_For_Display_Column
                   (Filter_Raw,
                    Input_Scroll_Columns
                      (Filter_Raw, Snapshot.Text_Cursor_Position, Filter_Text_W, Line_Height))
            else 0);
         Filter_Shown  : constant UString :=
           To_Unbounded_String
             (Filter_Raw (Filter_Raw'First + Natural'Min (Filter_Skip, Filter_Raw'Length) .. Filter_Raw'Last));
         Scope_Key : constant String :=
           (case Snapshot.Search_Scope is
              when Files.Types.Filter_Here => "search.scope.here",
              when Files.Types.Search_Names => "search.scope.names",
              when Files.Types.Search_Contents => "search.scope.contents");
      begin
         Add_Input_Field
           (Filter_X,
            Toolbar_Input_Y,
            Filter_W,
            Toolbar_Input_H,
            Input_Color,
            Border_Color);
         Add_Text
           (Saturating_Add (Filter_X, Guikit.Layout.Input_Field_Padding),
            Toolbar_Input_Text_Y,
            Filter_Text_W,
            Toolbar_Input_Text_H,
            (if Length (Snapshot.Filter_Text) = 0
             then To_Unbounded_String (Files.Localization.Text ("filter.placeholder"))
             else Filter_Shown),
            (if Length (Snapshot.Filter_Text) = 0 then Muted_Text_Color else Text_Color),
            Fit => True);
         if Snapshot.Focus = Files.Types.Focus_Filter_Input then
            Add_Border (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Border_Color);
            Add_Focus_Ring (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H);
            Add_Caret
              (Filter_X,
               Toolbar_Input_Y,
               Filter_W,
               Toolbar_Input_H,
               Filter_Shown,
               (if Snapshot.Text_Cursor_Position > Filter_Skip
                then Snapshot.Text_Cursor_Position - Filter_Skip else 0));
         elsif Has_Hover
           and then Contains_Point
             (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Hover_X, Hover_Y)
         then
            Add_Border (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Hover_Color);
         end if;
         if Is_Pressed (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H) then
            Add_Border (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Pressed_Color);
         end if;

         if Scope_Chip.Visible then
            declare
               --  The scope chip is a button: clicking it cycles the search
               --  scope. Give it the raised button look used by the overlay/
               --  close buttons -- a persistent Pane_Color fill and border that
               --  lifts to Hover_Color/Pressed_Color on interaction and to
               --  Selection_Color while recursive search results are on screen --
               --  rather than the recessed Input_Color look of a text field.
               Chip_Hovered : constant Boolean :=
                 Has_Hover
                 and then Contains_Point
                   (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height, Hover_X, Hover_Y);
               Chip_Pressed : constant Boolean :=
                 Is_Pressed (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height);
               Chip_Active  : constant Boolean := Snapshot.Search_Results_Active;
            begin
               Add_Rect
                 (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height,
                  (if Chip_Active then Selection_Color
                   elsif Chip_Pressed then Pressed_Color
                   elsif Chip_Hovered then Hover_Color
                   else Pane_Color));
               Add_Border
                 (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height, Border_Color);
               Add_Text
                 (Saturating_Add (Scope_Chip.X, Guikit.Layout.Input_Field_Padding),
                  Toolbar_Input_Text_Y,
                  (if Scope_Chip.Width > 2 * Guikit.Layout.Input_Field_Padding
                   then Scope_Chip.Width - 2 * Guikit.Layout.Input_Field_Padding
                   else 0),
                  Toolbar_Input_Text_H,
                  Localized (Scope_Key),
                  (if Chip_Active then Text_Color else Muted_Text_Color),
                  Fit => True);
               --  The chip's own tooltip, added before the filter field's, so it
               --  wins the first-match hit-test for points over the chip and
               --  explains the scope control rather than the filter input.
               Add_Tooltip
                 (Scope_Chip.X,
                  Scope_Chip.Y,
                  Scope_Chip.Width,
                  Scope_Chip.Height,
                  "search.scope.tooltip");
               Add_Accessibility_Node
                 (Role_Button,
                  Scope_Chip.X,
                  Scope_Chip.Y,
                  Scope_Chip.Width,
                  Scope_Chip.Height,
                  Localized ("accessibility.search_scope"),
                  Localized (Scope_Key),
                  Enabled => True,
                  Focused => False);
            end;
         end if;
      end;
      Add_Command_Tooltip
        (Toolbar.Right_X,
         Toolbar_Input_Y,
         Toolbar.Right_Width,
         Toolbar_Input_H,
         Files.Commands.Focus_Filter_Input_Command);
      Add_Accessibility_Node
        (Role_Text_Input,
         Toolbar.Right_X,
         Toolbar_Input_Y,
         Toolbar.Right_Width,
         Toolbar_Input_H,
         Localized (Files.Commands.Name_Key (Files.Commands.Focus_Filter_Input_Command)),
         Snapshot.Filter_Text,
         Enabled => True,
         Focused => Snapshot.Focus = Files.Types.Focus_Filter_Input);

      --  The view-mode switcher is a segmented control over the view-mode region.
      declare
         --  Labels come from Files.UI.View_Mode_Segments so the widths drawn
         --  here match the widths the click hit-test measures; the renderer only
         --  adds the per-cell tooltip and enabled state.
         View_Segments : Guikit.Segmented.Segment_Vectors.Vector := Files.UI.View_Mode_Segments;
         Seg_Rects     : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Seg_Text      : Guikit.Draw.Text_Command_Vectors.Vector;
         Seg_Tips      : Guikit.Draw.Tooltip_Command_Vectors.Vector;
         Seg_Nodes     : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Active        : constant Natural :=
           (case Snapshot.View_Mode is
               when Files.Types.Small_Icons => 1,
               when Files.Types.Large_Icons => 2,
               when Files.Types.Details     => 3);

         procedure Enrich (Cell : Positive; Command : Files.Commands.Registered_Command_Id) is
            S : Guikit.Segmented.Segment := View_Segments.Element (Cell);
         begin
            S.Tooltip := Command_Label (Command);
            S.Enabled := Snapshot.Command_Enabled (Command);
            View_Segments.Replace_Element (Cell, S);
         end Enrich;
      begin
         Enrich (1, Files.Commands.Select_Small_Icons_Command);
         Enrich (2, Files.Commands.Select_Large_Icons_Command);
         Enrich (3, Files.Commands.Select_Details_Command);
         Guikit.Segmented.Build_Frame
           (Segments      => View_Segments,
            Active        => Active,
            Region_X      => Bottom.View_Mode_X,
            Region_Y      => Bottom_Y,
            Region_Width  => Bottom.View_Mode_Width,
            Region_Height => Layout.Bottom_Bar_Height,
            Clip_Width    => Width,
            Clip_Height   => Height,
            Line_Height   => Line_Height,
            Hover_X       => (if Has_Hover then Hover_X else -1),
            Hover_Y       => (if Has_Hover then Hover_Y else -1),
            --  Cells fill the full bar, but sit the labels on the shared bottom-bar
            --  text baseline instead of centring them in the taller cell.
            Label_Inset   => Bottom_Content_Y - Bottom_Y,
            Rectangles    => Seg_Rects,
            Text          => Seg_Text,
            Tooltips      => Seg_Tips,
            Accessibility => Seg_Nodes);
         for C of Seg_Rects loop
            Result.Rectangles.Append (C);
         end loop;
         for C of Seg_Text loop
            Result.Text.Append (C);
         end loop;
         for C of Seg_Tips loop
            Add_Tooltip_Text (C.X, C.Y, C.Width, C.Height, C.Text);
         end loop;
         for N of Seg_Nodes loop
            Add_Accessibility_Node
              (N.Role,
               N.X,
               N.Y,
               N.Width,
               N.Height,
               N.Name,
               N.Description,
               N.Enabled,
               N.Selected,
               N.Focused);
         end loop;
      end;
      declare
         Hovered : constant Boolean :=
           Has_Hover
           and then Contains_Point
             (Bottom.Sort_Button_X,
              Bottom_Y,
              Bottom.Sort_Button_Width,
              Layout.Bottom_Bar_Height,
              Hover_X,
              Hover_Y);
         Pressed : constant Boolean :=
           Is_Pressed (Bottom.Sort_Button_X, Bottom_Y, Bottom.Sort_Button_Width, Layout.Bottom_Bar_Height);
      begin
         Add_Button (Bottom.Sort_Button_X, Bottom.Sort_Button_Width, Snapshot.Sort_Menu_Open, Hovered, Pressed);
         declare
            Field_Label : constant String := Sort_Field_Label (Snapshot.Sort_Field);
            Arrow_Text  : constant String := Direction_Text;
            Cell_W      : constant Positive :=
              Guikit.Layout.Caret_Advance_Width (Line_Height);
            Label_W     : constant Natural :=
              Saturating_Multiply (Files.UTF8.Display_Units (Field_Label), Cell_W);
            --  Tighter than a full monospace space so the direction arrow sits
            --  close to the sort field it belongs to.
            Arrow_Gap   : constant Natural := Cell_W / 2;
            Arrow_W     : constant Natural :=
              Saturating_Multiply (Files.UTF8.Display_Units (Arrow_Text), Cell_W);
            --  Actual field + gap + arrow width drawn. The button is sized assuming
            --  a full space before the arrow, so it is a touch wider; centre the
            --  drawn content within the button rather than left-aligning it.
            Rendered_W  : constant Natural :=
              Saturating_Add (Label_W, Saturating_Add (Arrow_Gap, Arrow_W));
            Text_X0     : constant Natural :=
              Saturating_Add
                (Bottom.Sort_Button_X,
                 (if Bottom.Sort_Button_Width > Rendered_W
                  then (Bottom.Sort_Button_Width - Rendered_W) / 2
                  else Guikit.Layout.Input_Field_Padding));
            Content_W   : constant Natural :=
              (if Bottom.Sort_Button_Width > Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2)
               then Bottom.Sort_Button_Width - Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2)
               else 0);
            Arrow_X     : constant Natural :=
              Saturating_Add (Text_X0, Saturating_Add (Label_W, Arrow_Gap));
            Sort_Color  : constant Render_Color :=
              Command_Color (Files.Commands.Toggle_Sort_Menu_Command);
         begin
            Add_Text
              (Text_X0,
               Bottom_Content_Y,
               Content_W,
               Bottom_Content_H,
               To_Unbounded_String (Field_Label),
               Sort_Color,
               Fit => False);
            if Content_W > Saturating_Add (Label_W, Arrow_Gap) then
               Add_Text
                 (Arrow_X,
                  Bottom_Content_Y,
                  Content_W - Label_W - Arrow_Gap,
                  Bottom_Content_H,
                  To_Unbounded_String (Arrow_Text),
                  Sort_Color,
                  Fit => False);
            end if;
         end;
         Add_Command_Tooltip
           (Bottom.Sort_Button_X,
            Bottom_Content_Y,
            Bottom.Sort_Button_Width,
            Bottom_Content_H,
            Files.Commands.Toggle_Sort_Menu_Command);
         Add_Accessibility_Node
           (Role_Button,
            Bottom.Sort_Button_X,
            Bottom_Content_Y,
            Bottom.Sort_Button_Width,
            Bottom_Content_H,
            Sort_Button_Label,
            Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Sort_Menu_Command)),
            Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Sort_Menu_Command),
            Selected => Snapshot.Sort_Menu_Open);
      end;
      --  The counts area doubles as the hidden-count control: clicking it
      --  toggles Show_Hidden_Files. The free-space field to its right is a
      --  separate, non-interactive field, so the toggle's hover/press/tooltip
      --  affordances stop at the divider rather than spanning the whole region.
      declare
         Pad       : constant Natural := 4;
         Cell_W    : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);
         Free_Text : constant String := Free_Space_Label (Snapshot);
         Free_W    : constant Natural := Free_Space_Label_Width (Snapshot, Line_Height);
         --  The counts/free split, shared with the click hit-test so the toggle's
         --  hover/press/tooltip area and the separate free-space field agree.
         Toggle_W, Divider_X, Free_X, Free_Field_W : Natural;
         --  Fill the whole button height (matching the neighbouring bottom-bar
         --  controls and this control's own full-height hit region), not just
         --  the padding-inset content box, so hover/press has no uncovered
         --  stripe at the bottom.
         Info_Btn_Y : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Bottom_Y + 1 else Bottom_Y);
         Info_Btn_H : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
            else Layout.Bottom_Bar_Height);
      begin
         Files.UI.Split_Status_Region
           (Bottom.Info_X, Bottom.Info_Width, Free_W,
            Toggle_W, Divider_X, Free_X, Free_Field_W, Line_Height);
         declare
            Show_Free : constant Boolean := Free_Field_W > 0;
            Counts_W  : constant Natural := (if Toggle_W > 2 * Pad then Toggle_W - 2 * Pad else 0);
            Info_Text : constant UString := Bottom_Info_Text;
            --  When the labelled counts do not fit the available width, collapse
            --  to just the three numbers (hidden / visible / selected),
            --  slash-separated and label-less. The error line is never collapsed.
            Compact   : constant String :=
              Natural_Text (Snapshot.Hidden_Count) & "/"
              & Natural_Text (Snapshot.Visible_Count) & "/"
              & Natural_Text (Snapshot.Selected_Count);
            Use_Compact : constant Boolean :=
              Length (Snapshot.Last_Error_Key) = 0
              and then Saturating_Multiply (Files.UTF8.Display_Units (To_String (Info_Text)), Cell_W) > Counts_W;
            Status_Text : constant UString :=
              (if Use_Compact then To_Unbounded_String (Compact) else Info_Text);
            --  The counts area is the clickable hidden-files toggle, so its text
            --  is drawn in the active control colour (white when enabled), like
            --  the neighbouring toggle buttons, rather than the muted info colour
            --  used for the non-clickable free-space field. The error line keeps
            --  the error colour.
            Counts_Color : constant Render_Color :=
              (if Length (Snapshot.Last_Error_Key) > 0 then Error_Text_Color
               else Command_Color (Files.Commands.Toggle_Hidden_Files_Command));
            --  The counts tooltip carries the toggle action plus a legend of the
            --  three numbers (hidden / visible / selected, in display order), so
            --  their meaning is clear even when the small-window form drops the
            --  labels down to "N/N/N". The legend reuses the status labels, so it
            --  is localized and matches the compact separator.
            Counts_Tip : constant UString :=
              Command_Tooltip_Text (Files.Commands.Toggle_Hidden_Files_Command)
              & To_Unbounded_String
                  (" ("
                   & Files.Localization.Text ("status.hidden") & " / "
                   & Files.Localization.Text ("status.visible") & " / "
                   & Files.Localization.Text ("status.selected")
                   & ")");
         begin
            Add_Rect
              (Bottom.Info_X,
               Info_Btn_Y,
               Toggle_W,
               Info_Btn_H,
               (if not Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command)
                then Bottom_Bar_Color
                elsif Is_Pressed (Bottom.Info_X, Bottom_Y, Toggle_W, Layout.Bottom_Bar_Height)
                then Pressed_Color
                elsif Has_Hover
                  and then Contains_Point
                    (Bottom.Info_X, Bottom_Y, Toggle_W, Layout.Bottom_Bar_Height, Hover_X, Hover_Y)
                then Hover_Color
                else Bottom_Bar_Color));
            Add_Text
              (Saturating_Add (Bottom.Info_X, Pad),
               Bottom_Content_Y,
               Counts_W,
               Bottom_Content_H,
               Status_Text,
               Counts_Color,
               Fit => True);
            if Show_Free then
               declare
                  --  The free field's interactive region: from the divider to the
                  --  right edge of the info area, mirroring the click hit-test.
                  Free_Region_X : constant Natural := Divider_X;
                  Free_Region_W : constant Natural :=
                    (if Saturating_Add (Bottom.Info_X, Bottom.Info_Width) > Divider_X
                     then Saturating_Add (Bottom.Info_X, Bottom.Info_Width) - Divider_X
                     else Free_Field_W);
               begin
                  --  Clicking the field toggles free/used space, so it gets the
                  --  same hover/press affordance as the neighbouring toggles.
                  Add_Rect
                    (Free_Region_X,
                     Info_Btn_Y,
                     Free_Region_W,
                     Info_Btn_H,
                     (if not Snapshot.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command)
                      then Bottom_Bar_Color
                      elsif Is_Pressed (Free_Region_X, Bottom_Y, Free_Region_W, Layout.Bottom_Bar_Height)
                      then Pressed_Color
                      elsif Has_Hover
                        and then Contains_Point
                          (Free_Region_X, Bottom_Y, Free_Region_W, Layout.Bottom_Bar_Height, Hover_X, Hover_Y)
                      then Hover_Color
                      else Bottom_Bar_Color));
                  --  Span the full bar height (matching the button fills), not
                  --  just the inset content band, so the divider reaches top to
                  --  bottom.
                  Add_Rect
                    (Divider_X,
                     Saturating_Add (Bottom_Y, 1),
                     1,
                     (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
                      else Layout.Bottom_Bar_Height),
                     Border_Color);
                  if Free_Space_Bar_Active (Snapshot) then
                     --  Bar mode: a scrollbar-like track whose blue core width is
                     --  the fraction of disk space used.
                     declare
                        Bar_H  : constant Natural := Natural'Max (8, Saturating_Multiply (Line_Height, 2) / 3);
                        --  Centre the bar in the field's full height (the hover
                        --  rect band), not the smaller inset content band.
                        Bar_Y  : constant Natural :=
                          (if Info_Btn_H > Bar_H
                           then Saturating_Add (Info_Btn_Y, (Info_Btn_H - Bar_H) / 2)
                           else Info_Btn_Y);
                        Bar_W  : constant Natural :=
                          (if Free_Field_W > Pad then Free_Field_W - Pad else 0);
                        --  Centre the bar in the field's interactive region so the
                        --  margins before and after it are equal.
                        Bar_X  : constant Natural :=
                          (if Free_Region_W > Bar_W
                           then Saturating_Add (Free_Region_X, (Free_Region_W - Bar_W) / 2)
                           else Free_Region_X);
                        Used   : constant Long_Long_Integer :=
                          Snapshot.Total_Space_Bytes - Snapshot.Free_Space_Bytes;
                        --  Warn in red when 10% or less of the disk is free.
                        Fill_Color : constant Render_Color :=
                          (if Snapshot.Free_Space_Bytes <= Snapshot.Total_Space_Bytes / 10
                           then Error_Text_Color
                           else Selection_Color);
                     begin
                        if Bar_W > 0 then
                           Guikit.Widgets.Draw_Meter
                             (Result.Rectangles, Layout.Width, Layout.Height,
                              Bar_X, Bar_Y, Bar_W, Bar_H,
                              Used, Snapshot.Total_Space_Bytes,
                              Input_Color, Fill_Color);
                           Add_Border (Bar_X, Bar_Y, Bar_W, Bar_H, Border_Color);
                        end if;
                     end;
                  else
                     Add_Text
                       (Free_X,
                        Bottom_Content_Y,
                        Free_Field_W,
                        Bottom_Content_H,
                        To_Unbounded_String (Free_Text),
                        Command_Color (Files.Commands.Toggle_Free_Space_Display_Command),
                        Fit => True);
                  end if;
                  --  Tooltip describes the current mode and flips after a toggle.
                  Add_Tooltip
                    (Free_Region_X,
                     Bottom_Content_Y,
                     Free_Region_W,
                     Bottom_Content_H,
                     (if Free_Space_Bar_Active (Snapshot) then "status.space_bar.tooltip"
                      elsif Snapshot.Show_Used_Space then "status.used_space.tooltip"
                      else "status.free_space.tooltip"));
                  Add_Accessibility_Node
                    (Role_Button,
                     Free_Region_X,
                     Bottom_Content_Y,
                     Free_Region_W,
                     Bottom_Content_H,
                     Command_Label (Files.Commands.Toggle_Free_Space_Display_Command),
                     Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Free_Space_Display_Command)),
                     Enabled => Snapshot.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command));
               end;
            end if;
            Add_Tooltip_Text
              (Bottom.Info_X,
               Bottom_Content_Y,
               Toggle_W,
               Bottom_Content_H,
               Counts_Tip);
            Add_Accessibility_Node
              (Role_Button,
               Bottom.Info_X,
               Bottom_Content_Y,
               Toggle_W,
               Bottom_Content_H,
               Command_Label (Files.Commands.Toggle_Hidden_Files_Command),
               Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Hidden_Files_Command)),
               Enabled => Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command));
         end;
      end;
      declare
         Info_Btn_Y : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Bottom_Y + 1 else Bottom_Y);
         Info_Btn_H : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
            else Layout.Bottom_Bar_Height);
      begin
         Add_Rect
           (Bottom.Info_Pane_X,
            Info_Btn_Y,
            Bottom.Info_Pane_Width,
            Info_Btn_H,
            (if not Snapshot.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command) then Pane_Color
             elsif Snapshot.Info_Pane_Open
             then Selection_Color
             elsif Is_Pressed
               (Bottom.Info_Pane_X,
                Bottom_Y,
                Bottom.Info_Pane_Width,
                Layout.Bottom_Bar_Height)
             then Pressed_Color
             elsif Has_Hover
               and then Contains_Point
                 (Bottom.Info_Pane_X,
                  Bottom_Y,
                  Bottom.Info_Pane_Width,
                  Layout.Bottom_Bar_Height,
                  Hover_X,
                  Hover_Y)
             then Hover_Color
             else Bottom_Bar_Color));
      end;
      Add_Text
        (Saturating_Add (Bottom.Info_Pane_X, 4),
         Bottom_Content_Y,
         (if Bottom.Info_Pane_Width > 8 then Bottom.Info_Pane_Width - 8 else 0),
         Bottom_Content_H,
         Bottom_Command_Label (Files.Commands.Toggle_Info_Pane_Command),
         Command_Color (Files.Commands.Toggle_Info_Pane_Command),
         Fit => True);
      Add_Command_Tooltip
        (Bottom.Info_Pane_X,
         Bottom_Content_Y,
         Bottom.Info_Pane_Width,
         Bottom_Content_H,
         Files.Commands.Toggle_Info_Pane_Command);
      Add_Accessibility_Node
        (Role_Button,
         Bottom.Info_Pane_X,
         Bottom_Content_Y,
         Bottom.Info_Pane_Width,
         Bottom_Content_H,
         Command_Label (Files.Commands.Toggle_Info_Pane_Command),
         Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Info_Pane_Command)),
         Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command),
         Selected => Snapshot.Info_Pane_Open);
   end Draw_Toolbar;
