with Guikit.Text_Fields;
separate (Files.Rendering.Build_Frame_Commands.Draw_Toolbar)
   --  The path field: its breadcrumbs or the text typed in it.
   procedure Draw_Path_Bar is
      Text_Region : constant Field_Text_Region := Path_Field_Text_Region (Toolbar, Width, Line_Height);
      --  The box, as the click zone hit-tests it.
      Path_X      : constant Natural := Text_Region.Field_X;
      Path_W      : constant Natural := Text_Region.Field_Width;
      Focused     : constant Boolean := Snapshot.Focus = Files.UI_Types.Focus_Path_Input;
      Path_Raw    : constant String := To_String (Snapshot.Path_Input_Text);
      --  While focused, start the text far enough in that the caret shows.
      View        : constant Guikit.Text_Fields.View :=
        (if Focused
         then Field_View (Path_Raw, Snapshot.Text_Cursor_Position, Text_Region.Width, Line_Height)
         else (Skip_Bytes => 0, Caret_X => 0));

      --  Favorite toggle: a filled star when the current directory is a
      --  favorite, an empty star when not, drawn at the left of the path bar
      --  ahead of the breadcrumbs/edit field in both modes.
      procedure Draw_Favorite_Star (Star : Path_Favorite_Star_Bounds) is
         Star_Hovered : constant Boolean :=
           Has_Hover
           and then Contains_Point (Star.X, Star.Y, Star.Width, Star.Height, Hover_X, Hover_Y);
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
      end Draw_Favorite_Star;

      --  The path as typed, scrolled so the caret shows: the edit field's
      --  text, also shown when there are no breadcrumbs.
      procedure Draw_Edit_Text is
      begin
         Add_Text
           (Text_Region.X,
            Toolbar_Input_Text_Y,
            Text_Region.Width,
            Toolbar_Input_Text_H,
            To_Unbounded_String (Path_Raw (Path_Raw'First + View.Skip_Bytes .. Path_Raw'Last)),
            Fit => True);
      end Draw_Edit_Text;

      --  The breadcrumb segments, '>' between them, each clickable one a
      --  button with its ancestor path.
      procedure Draw_Breadcrumbs is
      begin
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
                    (Guikit.Layout.Saturating_Add (Guikit.Layout.Saturating_Add (Seg.X, Seg.Width), Advance),
                     Toolbar_Input_Text_Y,
                     Advance,
                     Toolbar_Input_Text_H,
                     To_Unbounded_String (Breadcrumb_Separator_Text),
                     Color => Muted_Text_Color);
               end if;
            end;
         end loop;
      end Draw_Breadcrumbs;

      Star : constant Path_Favorite_Star_Bounds := Path_Favorite_Star_Region (Width, Line_Height);
   begin
      Add_Input_Field
        (Path_X,
         Toolbar_Input_Y,
         Path_W,
         Toolbar_Input_H,
         (if Snapshot.Path_Input_Valid then Input_Color else Input_Error_Color),
         Border_Color);
      if Star.Visible then
         Draw_Favorite_Star (Star);
      end if;
      if Focused or else Breadcrumb_Rows.Is_Empty then
         Draw_Edit_Text;
      else
         Draw_Breadcrumbs;
      end if;
      Draw_Field_State (Text_Region, Focused, Snapshot.Path_Input_Valid, View.Caret_X);
      Add_Command_Tooltip (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Files.Commands.Focus_Path_Input_Command);
      --  The field's own box, not its whole toolbar section: a screen
      --  reader's request on it is answered by focusing the field
      --  (Files.Events.Translate_Field_Request matches exactly this box).
      Add_Accessibility_Node
        (Role_Text_Input,
         Path_X,
         Toolbar_Input_Y,
         Path_W,
         Toolbar_Input_H,
         Localized (Files.Commands.Name_Key (Files.Commands.Focus_Path_Input_Command)),
         Path_Input_Accessible_Description,
         Enabled => True,
         Focused => Focused);
   end Draw_Path_Bar;
