with Files.Rendering.Layouts.Tree;
with Guikit.Menu_Tree;

separate (Files.Rendering.Build_Frame_Commands)
   --  The folder tree panel, and its pick bar when choosing a destination.
   procedure Draw_Tree_Panel is
      use Files.Rendering.Layouts.Tree;
      --  Over everything while it picks a destination.
      As_Overlay : constant Boolean := Snapshot.Tree_Pick_Active;
      --  Drawn here, then added to the layer the panel is on.
      Rectangles : Rectangle_Command_Vectors.Vector;
      Texts      : Text_Command_Vectors.Vector;
      Pick       : constant Tree_Pick_Button_Layout :=
        (if Snapshot.Tree_Pick_Active
         then Tree_Pick_Buttons (Tree_Panel)
         else (others => <>));

      --  The panel, its rows and the pick buttons as accessibility nodes;
      --  they stay caller-side because they carry the node path and focus.
      procedure Describe_For_Accessibility is
      begin
         Add_Accessibility_Node
           (Role_List,
            Tree_Panel.X,
            Tree_Panel.Y,
            Tree_Panel.Width,
            Tree_Panel.Height,
            Localized ("accessibility.tree_panel"));
         for I in 1 .. Natural (Tree_Rows_Layout.Length) loop
            declare
               Row  : constant Tree_Row_Layout := Tree_Rows_Layout.Element (Positive (I));
               Data : constant Files.Folder_Tree.Visible_Row :=
                 Snapshot.Tree_Rows.Element (Positive (Row.Visible_Row_Index));
            begin
               Add_Accessibility_Node
                 (Role_List_Item,
                  Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Data.Name,
                  Data.Path,
                  Enabled  => True,
                  Selected => Row.Selected,
                  --  Only while the tree has the keyboard (picker or Tab);
                  --  otherwise the grid's item holds the focus.
                  Focused  =>
                    Row.Selected
                    and then (Snapshot.Tree_Pick_Active or else Snapshot.Tree_Keyboard_Active));
            end;
         end loop;
         if Snapshot.Tree_Pick_Active and then Pick.Visible then
            Add_Accessibility_Node
              (Role_Button, Pick.Choose_X, Pick.Y, Pick.Button_Width, Pick.Height,
               Localized ("tree.pick.choose"));
            Add_Accessibility_Node
              (Role_Button, Pick.Cancel_X, Pick.Y, Pick.Button_Width, Pick.Height,
               Localized ("tree.pick.cancel"));
         end if;
      end Describe_For_Accessibility;

   begin
      declare
         Title : constant UString :=
           (if Snapshot.Tree_Pick_Active
            then (if Snapshot.Tree_Pick_Moving
                  then Localized ("tree.pick.move")
                  else Localized ("tree.pick.copy"))
            else Localized ("tree.panel.title"));
         Config : constant Guikit.Menu_Tree.Menu_Tree_Configuration :=
           (Line_Height     => Line_Height,
            Text_Padding    => Root_Selector_Padding (Line_Height),
            Title_Height    => Tree_Panel.Row_Height,
            Expanded_Glyph  => To_Unbounded_String (Tree_Expander_Expanded_Text),
            Collapsed_Glyph => To_Unbounded_String (Tree_Expander_Collapsed_Text));
         Rows    : Guikit.Menu_Tree.Menu_Tree_Row_Vectors.Vector;
         Buttons : Guikit.Menu_Tree.Menu_Tree_Button_Vectors.Vector;
      begin
         for I in 1 .. Natural (Tree_Rows_Layout.Length) loop
            declare
               Row  : constant Tree_Row_Layout := Tree_Rows_Layout.Element (Positive (I));
               Data : constant Files.Folder_Tree.Visible_Row :=
                 Snapshot.Tree_Rows.Element (Positive (Row.Visible_Row_Index));
            begin
               Rows.Append
                 (Guikit.Menu_Tree.Menu_Tree_Row'
                    --  A folder whose children are being read says so.
                    (Label          =>
                       (if Data.Loading then Data.Name & " " & Localized ("tree.loading") else Data.Name),
                     X              => Row.X,
                     Y              => Row.Y,
                     Width          => Row.Width,
                     Height         => Row.Height,
                     Triangle_X     => Row.Triangle_X,
                     Triangle_Width => Row.Triangle_W,
                     Has_Children   => Row.Has_Children,
                     Expanded       => Row.Expanded,
                     Selected       => Row.Selected,
                     Hovered        =>
                       Is_Hovered (Row.X, Row.Y, Row.Width, Row.Height),
                     Pressed        => Is_Pressed (Row.X, Row.Y, Row.Width, Row.Height)));
            end;
         end loop;

         if Snapshot.Tree_Pick_Active and then Pick.Visible then
            Buttons.Append
              (Guikit.Menu_Tree.Menu_Tree_Button'
                 (Label   => Localized ("tree.pick.choose"),
                  X       => Pick.Choose_X,
                  Y       => Pick.Y,
                  Width   => Pick.Button_Width,
                  Height  => Pick.Height,
                  Hovered =>
                    Is_Hovered (Pick.Choose_X, Pick.Y, Pick.Button_Width, Pick.Height),
                  Pressed => Is_Pressed (Pick.Choose_X, Pick.Y, Pick.Button_Width, Pick.Height)));
            Buttons.Append
              (Guikit.Menu_Tree.Menu_Tree_Button'
                 (Label   => Localized ("tree.pick.cancel"),
                  X       => Pick.Cancel_X,
                  Y       => Pick.Y,
                  Width   => Pick.Button_Width,
                  Height  => Pick.Height,
                  Hovered =>
                    Is_Hovered (Pick.Cancel_X, Pick.Y, Pick.Button_Width, Pick.Height),
                  Pressed => Is_Pressed (Pick.Cancel_X, Pick.Y, Pick.Button_Width, Pick.Height)));
         end if;

         --  Destination picking blocks the rest of the window; the ordinary
         --  folder tree sidebar is not modal.
         if Snapshot.Tree_Pick_Active then
            Draw_Modal_Backdrop;
         end if;

         Guikit.Menu_Tree.Draw_Frame
           (Rectangles    => Rectangles,
            Text          => Texts,
            Clip_Width    => Layout.Width,
            Clip_Height   => Layout.Height,
            Region_X      => Tree_Panel.X,
            Region_Y      => Tree_Panel.Y,
            Region_Width  => Tree_Panel.Width,
            Region_Height => Tree_Panel.Height,
            Title         => Title,
            Config        => Config,
            Rows          => Rows,
            Buttons       => Buttons);

         if Tree_Panel.Scrollbar_Visible then
            Guikit.Widgets.Draw_Scrollbar
              (Rectangles   => Rectangles,
               Clip_Width   => Layout.Width,
               Clip_Height  => Layout.Height,
               Track_X      => Tree_Panel.Scrollbar_X,
               Track_Y      => Tree_Panel.Scrollbar_Y,
               Track_Width  => Tree_Panel.Scrollbar_Width,
               Track_Height => Tree_Panel.Scrollbar_Track_Height,
               Thumb_Y      => Tree_Panel.Scrollbar_Thumb_Y,
               Thumb_Height => Tree_Panel.Scrollbar_Height,
               Track_Color  => Border_Color,
               Thumb_Color  => Selection_Color,
               Grip_Color   => Muted_Text_Color);
         end if;

         Describe_For_Accessibility;
      end;

      if As_Overlay then
         Result.Overlay_Rectangles.Append (Rectangles);
         Result.Overlay_Text.Append (Texts);
      else
         Result.Rectangles.Append (Rectangles);
         Result.Text.Append (Texts);
      end if;
      Draw_Close_Button (Tree_Panel.Close_Button, Overlay => As_Overlay);
   end Draw_Tree_Panel;
