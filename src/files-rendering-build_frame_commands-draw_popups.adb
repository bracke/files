separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Popups is
      --  The Quick Look panel, drawn from its own part of the snapshot.
      procedure Draw_Quick_Look (Look : Quick_Look_Snapshot) is separate;
   begin
      if Snapshot.Quick_Look.Open then
         Draw_Quick_Look (Snapshot.Quick_Look);
      end if;

      if Snapshot.Label_Picker_Open then
         declare
            Picker  : constant Label_Picker_Layout :=
              Calculate_Label_Picker_Layout (Layout, Line_Height);
            Margin  : constant Natural := Natural'Max (Command_Palette_Padding (Line_Height), Line_Height / 2);
            Title_X : constant Natural := Guikit.Layout.Saturating_Add (Picker.X, Margin);
            Title_Y : constant Natural :=
              Guikit.Layout.Saturating_Add
                (Picker.Y, Natural'Max (Guikit.Layout.Scaled (4, Line_Height), Line_Height / 4));
            --  The accent band along the panel's top edge.
            Accent_H : constant Natural := Natural'Min (Guikit.Layout.Scaled (3, Line_Height), Picker.Height);
            --  The keyboard highlight's second ring sits this far inside a swatch.
            Ring_Inset : constant Natural := Guikit.Layout.Scaled (2, Line_Height);
            Title_W : constant Natural :=
              (if Picker.Width > Saturating_Multiply (Margin, 2)
               then Picker.Width - Saturating_Multiply (Margin, 2) else Picker.Width);
         begin
            --  The picker consumes all background input until a color is
            --  chosen or it is dismissed, so expose only the picker controls
            --  to assistive technology while it is open.
            Result.Accessibility.Clear;
            Add_Overlay_Drop_Shadow (Picker.X, Picker.Y, Picker.Width, Picker.Height);
            Add_Overlay_Rect (Picker.X, Picker.Y, Picker.Width, Picker.Height, Pane_Color);
            Add_Overlay_Border (Picker.X, Picker.Y, Picker.Width, Picker.Height, Border_Color);
            Add_Overlay_Rect (Picker.X, Picker.Y, Picker.Width, Accent_H, Selection_Color);
            Add_Accessibility_Node
              (Role_Dialog, Picker.X, Picker.Y, Picker.Width, Picker.Height,
               Localized ("accessibility.label_picker"));
            Add_Overlay_Text
              (Title_X, Title_Y, Title_W, Line_Height,
               Localized ("label_picker.title"), Fit => True);

            for Index in Picker.Swatches'Range loop
               declare
                  Swatch  : constant Label_Swatch_Bounds := Picker.Swatches (Index);
                  Label   : constant Files.Types.Color_Label := Label_For_Swatch (Index);
                  Hovered : constant Boolean :=
                    Has_Hover
                    and then Contains_Point (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Hover_X, Hover_Y);
                  Highlighted : constant Boolean := Index = Snapshot.Label_Picker_Highlight;
                  Name    : constant UString :=
                    Localized
                      ((case Label is
                          when Files.Types.No_Label => "label.color.none",
                          when Files.Types.Red      => "label.color.red",
                          when Files.Types.Orange   => "label.color.orange",
                          when Files.Types.Yellow   => "label.color.yellow",
                          when Files.Types.Green    => "label.color.green",
                          when Files.Types.Blue     => "label.color.blue",
                          when Files.Types.Purple   => "label.color.purple",
                          when Files.Types.Gray     => "label.color.gray"));
               begin
                  if Label = Files.Types.No_Label then
                     --  The clear swatch is an empty bordered box rather than a
                     --  filled color, so it reads as "remove any label".
                     Add_Overlay_Rect
                       (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Pane_Color);
                  else
                     Add_Overlay_Rect
                       (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height,
                        Label_Render_Color (Label));
                  end if;
                  Add_Overlay_Border
                    (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height,
                     (if Hovered or else Highlighted then Selection_Color else Border_Color));
                  if Highlighted
                    and then Swatch.Width > 2 * Ring_Inset
                    and then Swatch.Height > 2 * Ring_Inset
                  then
                     --  A second inset ring so the keyboard highlight reads
                     --  distinctly from a plain mouse hover.
                     Add_Overlay_Border
                       (Swatch.X + Ring_Inset, Swatch.Y + Ring_Inset,
                        Swatch.Width - 2 * Ring_Inset, Swatch.Height - 2 * Ring_Inset,
                        Selection_Color);
                  end if;
                  Add_Accessibility_Node
                    (Role_Button, Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Name);
               end;
            end loop;

            Draw_Close_Button (Picker.X, Picker.Y, Picker.Width, Picker.Height, Overlay => True);
         end;
      end if;

      if Snapshot.Sort_Menu_Open and then Bottom.Sort_Button_Width > 0 then
         declare
            Menu      : constant Files.UI.Sort_Menu_Layout :=
              Files.UI.Calculate_Sort_Menu_Layout (Width, Height, Snapshot.Sort_Field, Line_Height);
            Row_H     : constant Natural := Menu.Row_Height;
            Rows_H    : constant Natural := Saturating_Multiply (Row_H, Menu.Row_Count);
            Menu_H    : constant Natural := Menu.Height;
            Menu_X    : constant Natural := Menu.X;
            Menu_Y    : constant Natural := Menu.Y;
            Menu_W    : constant Natural := Menu.Width;
            Rows_Y    : constant Natural := Menu.Rows_Y;
            Row_X     : constant Natural := Guikit.Layout.Saturating_Add (Menu_X, 1);
            Row_W     : constant Natural := (if Menu_W > 2 then Menu_W - 2 else 0);
         begin
            --  Keyboard and pointer routing are confined to the open menu;
            --  publish the same scope to assistive technology.
            Result.Accessibility.Clear;
            Add_Overlay_Drop_Shadow (Menu_X, Menu_Y, Menu_W, Menu_H);
            Add_Overlay_Rect (Menu_X, Menu_Y, Menu_W, Menu_H, Overlay_Color);
            Add_Overlay_Border (Menu_X, Menu_Y, Menu_W, Menu_H, Border_Color);
            Add_Accessibility_Node
              (Role_List,
               Menu_X,
               Menu_Y,
               Menu_W,
               Menu_H,
               Localized ("command.sort.menu"));

            declare
               --  Row backgrounds and label text are the shared list geometry --
               --  delegate them to Guikit.List_Panel. The chrome, 1px inter-row
               --  separators and the richer accessibility stay here. The sort menu
               --  has no selected accent bar, so each row's accent is set to the
               --  selection colour, which renders Draw_Palette_Row's accent
               --  invisible against a selected row's background.
               List_Rows    : Guikit.List_Panel.List_Panel_Row_Vectors.Vector;
               Discard_A11y : Guikit.Draw.Accessibility_Node_Vectors.Vector;
               Config : constant Guikit.List_Panel.List_Panel_Configuration :=
                 (Line_Height         => Line_Height,
                  Text_Padding        => Files.UI.Field_Padding (Line_Height),
                  Show_Alternate_Rows => False,
                  others              => <>);
            begin
               for Row in 1 .. Menu.Row_Count loop
                  declare
                     Field    : constant Files.Types.Sort_Field := Files.UI.Sort_Menu_Row_Field (Row);
                     Row_Y    : constant Natural :=
                       Guikit.Layout.Saturating_Add (Rows_Y, Saturating_Multiply (Natural (Row - 1), Row_H));
                     Selected : constant Boolean := Field = Snapshot.Sort_Field;
                     Hovered  : constant Boolean :=
                       Has_Hover and then Contains_Point (Menu_X, Row_Y, Menu_W, Row_H, Hover_X, Hover_Y);
                     Highlighted : constant Boolean := Row = Snapshot.Sort_Menu_Highlight;
                     Pressed  : constant Boolean := Is_Pressed (Menu_X, Row_Y, Menu_W, Row_H);
                     Enabled  : constant Boolean := Snapshot.Command_Enabled (Sort_Field_Command (Field));
                     Label    : constant UString :=
                       To_Unbounded_String
                         (Sort_Field_Label (Field)
                          & (if Selected then " " & Direction_Text else ""));
                  begin
                     List_Rows.Append
                       (Guikit.List_Panel.List_Panel_Row'
                          (Label            => Label,
                           Selected         => Selected,
                           Enabled          => Enabled,
                           Label_Color      => (if Enabled then Text_Color else Disabled_Text_Color),
                           Accent_Color     => Selection_Color,
                           Has_Background   => not Selected,
                           Background_Color =>
                             (if Pressed then Pressed_Color
                              elsif Hovered or else Highlighted then Hover_Color
                              else Overlay_Color),
                           others           => <>));
                  end;
               end loop;

               Guikit.List_Panel.Draw_Frame
                 (Rectangles    => Result.Overlay_Rectangles,
                  Text          => Result.Overlay_Text,
                  Accessibility => Discard_A11y,
                  Clip_Width    => Layout.Width,
                  Clip_Height   => Layout.Height,
                  Region_X      => Row_X,
                  Region_Y      => Rows_Y,
                  Region_Width  => Row_W,
                  Region_Height => Rows_H,
                  Config        => Config,
                  Rows          => List_Rows,
                  Draw_Chrome   => False,
                  Row_Height    => Row_H);

               for Row in 1 .. Menu.Row_Count loop
                  declare
                     Field : constant Files.Types.Sort_Field := Files.UI.Sort_Menu_Row_Field (Row);
                     Row_Y : constant Natural :=
                       Guikit.Layout.Saturating_Add (Rows_Y, Saturating_Multiply (Natural (Row - 1), Row_H));
                     Selected : constant Boolean := Field = Snapshot.Sort_Field;
                     Label : constant UString :=
                       To_Unbounded_String
                         (Sort_Field_Label (Field)
                          & (if Selected then " " & Direction_Text else ""));
                  begin
                     if Row > 1 then
                        Add_Overlay_Rect (Row_X, Row_Y, Row_W, 1, Border_Color);
                     end if;
                     Add_Accessibility_Node
                       (Role_List_Item,
                        Menu_X,
                        Row_Y,
                        Menu_W,
                        Row_H,
                        Label,
                        Localized (Files.Commands.Description_Key (Sort_Field_Command (Field))),
                        Enabled  => Snapshot.Command_Enabled (Sort_Field_Command (Field)),
                        Selected => Selected);
                  end;
               end loop;
            end;
         end;
      end if;
   end Draw_Popups;
