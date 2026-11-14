separate (Files.Rendering.Build_Frame_Commands.Draw_Overlay_Commands)
   --  The drive and place selector.
   procedure Draw_Root_Selector is
   begin
      --  The selector owns pointer and keyboard input while open.  Keep the
      --  inactive file view out of the accessibility frame.
      Result.Accessibility.Clear;
      if Root_Selector.Width > 0 and then Root_Selector.Height > 0 then
         Add_Overlay_Drop_Shadow
           (Root_Selector.X,
            Root_Selector.Y,
            Root_Selector.Width,
            Root_Selector.Height);
         Add_Overlay_Rect
           (Root_Selector.X,
            Root_Selector.Y,
            Root_Selector.Width,
            Root_Selector.Height,
            Overlay_Color);
         Add_Overlay_Border
           (Root_Selector.X, Root_Selector.Y,
            Root_Selector.Width, Root_Selector.Height, Border_Color);
      end if;
      Add_Accessibility_Node
        (Role_List,
         Root_Selector.X,
         Root_Selector.Y,
         Root_Selector.Width,
         Root_Selector.Height,
         Localized ("accessibility.root_selector"));

      if Natural (Root_Rows.Length) > 0 then
         declare
            First_Row  : constant Root_Path_Layout := Root_Rows.First_Element;
            Row_H      : constant Natural := Root_Selector.Row_Height;
            Inner_H    : constant Natural :=
              (if Row_H > Saturating_Multiply (Root_Selector_Padding (Line_Height), 2)
               then Row_H - Saturating_Multiply (Root_Selector_Padding (Line_Height), 2)
               else Row_H);
            Toolbar_Icon_Size : constant Natural :=
              Guikit.Layout.Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Field_Padding (Line_Height), 2));
            --  Uniform across rows (they share Row_Height), so compute once.
            Glyph_Size : constant Natural := Natural'Min (Toolbar_Icon_Size, Inner_H);
            List_Rows  : Guikit.List_Panel.List_Panel_Row_Vectors.Vector;
            --  List_Panel emits its own list/row accessibility; files keeps its
            --  richer per-row nodes (path + focused) below, so its nodes are
            --  discarded into a throwaway vector.
            Discard_A11y : Guikit.Draw.Accessibility_Node_Vectors.Vector;
            Config : constant Guikit.List_Panel.List_Panel_Configuration :=
              (Line_Height         => Line_Height,
               Text_Padding        => Root_Selector_Padding (Line_Height),
               Show_Alternate_Rows => False,
               others              => <>);
         begin
            --  Row backgrounds, the selected accent bar, and the label text are
            --  the common list geometry -- delegate them to Guikit.List_Panel.
            --  The folder glyph, inter-row separators, tooltips and the richer
            --  accessibility stay here (domain-specific).
            for Index in 1 .. Natural (Root_Rows.Length) loop
               declare
                  Row     : constant Root_Path_Layout := Root_Rows.Element (Positive (Index));
                  Hovered : constant Boolean :=
                    Has_Hover and then Contains_Point (Row.X, Row.Y, Row.Width, Row.Height, Hover_X, Hover_Y);
                  Pressed : constant Boolean := Is_Pressed (Row.X, Row.Y, Row.Width, Row.Height);
               begin
                  List_Rows.Append
                    (Guikit.List_Panel.List_Panel_Row'
                       (Label            => Snapshot.Roots (Positive (Row.Root_Index)).Label,
                        Selected         => Row.Selected,
                        Has_Background   => not Row.Selected,
                        Background_Color =>
                          (if Pressed then Pressed_Color
                           elsif Hovered then Hover_Color
                           else Overlay_Color),
                        others           => <>));
               end;
            end loop;

            Guikit.List_Panel.Draw_Frame
              (Rectangles    => Result.Overlay_Rectangles,
               Text          => Result.Overlay_Text,
               Accessibility => Discard_A11y,
               Clip_Width    => Width,
               Clip_Height   => Height,
               Region_X      => First_Row.X,
               Region_Y      => First_Row.Y,
               Region_Width  => First_Row.Width,
               --  The layout trims the last row to the dropdown; size the
               --  region from the rows themselves so it is not drawn past it.
               Region_Height =>
                 (declare
                    Last_Row : constant Root_Path_Layout := Root_Rows.Last_Element;
                    Bottom   : constant Natural := Guikit.Layout.Saturating_Add (Last_Row.Y, Last_Row.Height);
                  begin (if Bottom > First_Row.Y then Bottom - First_Row.Y else 0)),
               Config        => Config,
               Rows          => List_Rows,
               Draw_Chrome   => False,
               Row_Height    => Row_H,
               Leading_Icon_Width => Guikit.Layout.Saturating_Add (Glyph_Size, Root_Selector_Padding (Line_Height)));

            for Index in 1 .. Natural (Root_Rows.Length) loop
               declare
                  Row     : constant Root_Path_Layout := Root_Rows.Element (Positive (Index));
                  Row_Pad : constant Natural := Natural'Min (Root_Selector_Padding (Line_Height), Row.Height);
                  Glyph_X : constant Natural := Guikit.Layout.Saturating_Add (Row.X, Row_Pad);
                  Glyph_Y : constant Natural :=
                    (if Row.Height > Glyph_Size
                     then Guikit.Layout.Saturating_Add (Row.Y, (Row.Height - Glyph_Size) / 2)
                     else Row.Y);
               begin
                  if Index > 1 then
                     Add_Overlay_Rect (Row.X, Row.Y, Row.Width, 1, Border_Color);
                  end if;
                  if Glyph_Size > 0 then
                     Add_Overlay_Rect
                       (Glyph_X,
                        Guikit.Layout.Saturating_Add (Glyph_Y, Glyph_Size / 4),
                        Glyph_Size,
                        Natural'Max (1, Glyph_Size / 2),
                        Icon_Folder_Color);
                     Add_Overlay_Rect
                       (Guikit.Layout.Saturating_Add (Glyph_X, Glyph_Size / 4),
                        Glyph_Y,
                        Natural'Max (1, Glyph_Size / 2),
                        Natural'Max (1, Glyph_Size / 4),
                        Icon_Folder_Color);
                  end if;
                  Add_Command_Tooltip
                    (Row.X,
                     Row.Y,
                     Row.Width,
                     Row.Height,
                     Files.Commands.Open_Selected_Root_Command);
                  Add_Accessibility_Node
                    (Role_List_Item,
                     Row.X,
                     Row.Y,
                     Row.Width,
                     Row.Height,
                     Snapshot.Roots (Positive (Row.Root_Index)).Label,
                     Snapshot.Roots (Positive (Row.Root_Index)).Path,
                     Enabled  => True,
                     Selected => Row.Selected,
                     Focused  => Row.Selected);
               end;
            end loop;
         end;
      end if;
      Draw_Close_Button
        (Root_Selector.X, Root_Selector.Y, Root_Selector.Width, Root_Selector.Height,
         Overlay => True);
   end Draw_Root_Selector;
