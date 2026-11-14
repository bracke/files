separate (Files.Rendering.Build_Frame_Commands.Draw_Toolbar)
   --  The filter field and its search-scope chip.
   procedure Draw_Filter_Field is
   begin
      declare
         --  The chip is sized to its localized label so it never abbreviates;
         --  the filter field is narrowed to end before it (when it fits).
         Scope_Chip_W : constant Natural := Files.UI.Filter_Scope_Chip_Width (Line_Height);
         Scope_Chip : constant Guikit.Layout.Scope_Chip_Region :=
           Guikit.Layout.Filter_Scope_Chip_Region_Of (Toolbar, Scope_Chip_W, Line_Height);
         Text_Region   : constant Field_Text_Region := Filter_Field_Text_Region (Toolbar, Line_Height);
         --  The box, as the click zone hit-tests it.
         Filter_X      : constant Natural := Text_Region.Field_X;
         Filter_W      : constant Natural := Text_Region.Field_Width;
         Filter_Text_W : constant Natural := Text_Region.Width;
         Filter_Raw    : constant String := To_String (Snapshot.Filter_Text);
         Filter_Skip   : constant Natural :=
           (if Snapshot.Focus = Files.Types.Focus_Filter_Input
            then Guikit.Utf8.Byte_Offset_For_Display_Column
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
           (Text_Region.X,
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
                 (Guikit.Layout.Saturating_Add (Scope_Chip.X, Files.UI.Field_Padding (Line_Height)),
                  Toolbar_Input_Text_Y,
                  (if Scope_Chip.Width > 2 * Files.UI.Field_Padding (Line_Height)
                   then Scope_Chip.Width - 2 * Files.UI.Field_Padding (Line_Height)
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

   end Draw_Filter_Field;
