separate (Files.Rendering.Build_Frame_Commands)
   --  The window background and the toolbar: its buttons, then its fields.
   procedure Draw_Toolbar is
      procedure Draw_Path_Bar is separate;
      procedure Draw_Filter_Field is separate;
      procedure Draw_View_Switcher is separate;
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
           (Saturating_Add (Layout.Main_X, Layout.Main_Width),
            Layout.Main_Y,
            Layout.Info_Pane_Width,
            Layout.Main_Height,
            Pane_Color);
         Add_Rect
           (Saturating_Add (Layout.Main_X, Layout.Main_Width),
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
              Natural'Min (Guikit.Layout.Scaled (2, Line_Height), Button_H / 8);
            Inner_Pad    : constant Natural := Natural'Min (Guikit.Layout.Scaled (3, Line_Height), Button_W / 6);
            Group_Pad    : constant Natural := Natural'Min (Guikit.Layout.Scaled (8, Line_Height), Button_W / 4);
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
            --  The icon's margins inside a full-width button scale with it.
            Icon_Size : constant Natural :=
              (if Visible_W >= Toolbar.Button_Width - Guikit.Layout.Scaled (4, Line_Height)
               then Natural'Min (Visible_H, Toolbar.Button_Width - Guikit.Layout.Scaled (8, Line_Height))
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
      Draw_Path_Bar;
      Draw_Filter_Field;
      Draw_View_Switcher;
   end Draw_Toolbar;
