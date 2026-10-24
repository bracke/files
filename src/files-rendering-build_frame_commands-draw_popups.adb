separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Popups is
   begin
      if Snapshot.Quick_Look_Open then
         declare
            QL      : constant Quick_Look_Layout := Calculate_Quick_Look_Layout (Layout, Line_Height);
            Margin  : constant Natural := Natural'Max (Command_Palette_Padding, Line_Height / 2);
            Title_X : constant Natural := Saturating_Add (QL.X, Margin);
            Title_Y : constant Natural := Saturating_Add (QL.Y, Natural'Max (4, Line_Height / 4));
            Title_W : constant Natural :=
              (if QL.Width > Saturating_Multiply (Margin, 2)
               then QL.Width - Saturating_Multiply (Margin, 2) else QL.Width);
         begin
            --  Quick Look owns pointer and keyboard input while open.  Keep
            --  inactive file-view controls out of the accessibility frame;
            --  the dialog description identifies the item being previewed and
            --  updates as keyboard navigation changes the selection.
            Result.Accessibility.Clear;
            Add_Overlay_Drop_Shadow (QL.X, QL.Y, QL.Width, QL.Height);
            Add_Overlay_Rect (QL.X, QL.Y, QL.Width, QL.Height, Pane_Color);
            Add_Overlay_Border (QL.X, QL.Y, QL.Width, QL.Height, Border_Color);
            Add_Overlay_Rect (QL.X, QL.Y, QL.Width, Natural'Min (3, QL.Height), Selection_Color);
            Add_Accessibility_Node
              (Role_Dialog, QL.X, QL.Y, QL.Width, QL.Height,
               Localized ("accessibility.quick_look"), Snapshot.Quick_Look_Name);
            --  Panel title: the previewed item's name, which also serves as the
            --  content marker tests assert on for every kind.
            Add_Overlay_Text (Title_X, Title_Y, Title_W, Line_Height, Snapshot.Quick_Look_Name, Fit => True);

            case Snapshot.Quick_Look_Kind is
               when Files.Quick_Look.Image_Content =>
                  if Natural (Snapshot.Quick_Look_Image_Pixels.Length) > 0
                    and then Snapshot.Quick_Look_Image_Width > 0
                    and then Snapshot.Quick_Look_Image_Height > 0
                  then
                     declare
                        IW : constant Natural := Snapshot.Quick_Look_Image_Width;
                        IH : constant Natural := Snapshot.Quick_Look_Image_Height;
                        CW : constant Natural := QL.Content_Width;
                        CH : constant Natural := QL.Content_Height;
                        --  Fit the image inside the content box preserving aspect.
                        Height_Bound : constant Boolean :=
                          Saturating_Multiply (IW, CH) <= Saturating_Multiply (IH, CW);
                        Draw_W : constant Natural :=
                          (if Height_Bound then Saturating_Multiply (IW, CH) / IH else CW);
                        Draw_H : constant Natural :=
                          (if Height_Bound then CH else Saturating_Multiply (IH, CW) / IW);
                        Img_X  : constant Natural :=
                          Saturating_Add (QL.Content_X, (if CW > Draw_W then (CW - Draw_W) / 2 else 0));
                        Img_Y  : constant Natural :=
                          Saturating_Add (QL.Content_Y, (if CH > Draw_H then (CH - Draw_H) / 2 else 0));
                     begin
                        if Draw_W > 0 and then Draw_H > 0 then
                           --  One icon command carrying the decoded pixels; the
                           --  atlas gives it a high-resolution tile and it draws
                           --  at its aspect-correct size.
                           Result.Icons.Append
                             (Icon_Command'
                                (X                => Img_X,
                                 Y                => Img_Y,
                                 Size             => Draw_W,
                                 Icon_Id          => Snapshot.Quick_Look_Icon_Id,
                                 Theme_Name       => Snapshot.Theme_Name,
                                 Asset_Path       => Null_Unbounded_String,
                                 Thumbnail_Width  => IW,
                                 Thumbnail_Height => IH,
                                 Thumbnail_Pixels => Snapshot.Quick_Look_Image_Pixels,
                                 Overlay          => True,
                                 Draw_Width       => Draw_W,
                                 Draw_Height      => Draw_H,
                                 others           => <>));
                        end if;
                     end;
                  else
                     Add_Overlay_Text
                       (QL.Content_X, QL.Content_Y, QL.Content_Width, Line_Height,
                        Localized ("quick_look.empty"), Muted_Text_Color);
                  end if;
               when Files.Quick_Look.Text_Content =>
                  declare
                     Max_Lines : constant Natural :=
                       (if QL.Content_Height >= Line_Height then QL.Content_Height / Line_Height else 0);
                     Source_Lines : constant Natural :=
                       Natural (Snapshot.Quick_Look_Text_Lines.Length);
                     Content_Omitted : constant Boolean :=
                       Snapshot.Quick_Look_Text_Truncated or else Source_Lines > Max_Lines;
                     Preview_Lines : constant Natural :=
                       (if Content_Omitted and then Max_Lines > 0
                        then Max_Lines - 1
                        else Max_Lines);
                     Row       : Natural := 0;
                  begin
                     for Line of Snapshot.Quick_Look_Text_Lines loop
                        exit when Row >= Preview_Lines;
                        Add_Overlay_Text
                          (QL.Content_X,
                           Saturating_Add (QL.Content_Y, Saturating_Multiply (Row, Line_Height)),
                           QL.Content_Width, Line_Height, Line, Fit => True);
                        Row := Row + 1;
                     end loop;
                     if Content_Omitted and then Max_Lines > 0 then
                        Add_Overlay_Text
                          (QL.Content_X,
                           Saturating_Add (QL.Content_Y, Saturating_Multiply (Row, Line_Height)),
                           QL.Content_Width, Line_Height,
                           Localized ("quick_look.truncated"), Muted_Text_Color, Italic => True);
                     end if;
                  end;
               when Files.Quick_Look.Info_Content =>
                  declare
                     Text_Height : constant Natural := Saturating_Multiply (Line_Height, 2);
                     Reserved_H  : constant Natural :=
                       Saturating_Add (Margin, Text_Height);
                     Icon_Height_Available : constant Natural :=
                       (if QL.Content_Height > Reserved_H
                        then QL.Content_Height - Reserved_H
                        else 0);
                     Icon_Size : constant Natural :=
                       Natural'Min
                         (Saturating_Multiply (Line_Height, 3),
                          Natural'Min (QL.Content_Width, Icon_Height_Available));
                     Content_End_Y : constant Natural :=
                       Saturating_Add (QL.Content_Y, QL.Content_Height);
                     Row_Y     : Natural :=
                       Saturating_Add
                         (QL.Content_Y,
                          Saturating_Add
                            (Icon_Size, (if Icon_Size > 0 then Margin else 0)));
                     Size_Value : constant UString :=
                       (if Snapshot.Quick_Look_Size_Available
                        then To_Unbounded_String (Size_Text (Snapshot.Quick_Look_Size))
                        else Localized ("status.missing_metadata"));
                  begin
                     if Icon_Size > 0 then
                        Result.Icons.Append
                          (Icon_Command'
                             (X                => QL.Content_X,
                              Y                => QL.Content_Y,
                              Size             => Icon_Size,
                              Icon_Id          => Snapshot.Quick_Look_Icon_Id,
                              Theme_Name       => Snapshot.Theme_Name,
                              Asset_Path       => Null_Unbounded_String,
                              Thumbnail_Width  => 0,
                              Thumbnail_Height => 0,
                              Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector,
                              Overlay          => True,
                              Draw_Width       => 0,
                              Draw_Height      => 0,
                              others           => <>));
                     end if;
                     if Row_Y < Content_End_Y then
                        Add_Overlay_Text
                          (QL.Content_X, Row_Y, QL.Content_Width,
                           Natural'Min (Line_Height, Content_End_Y - Row_Y),
                           Snapshot.Quick_Look_Type, Muted_Text_Color, Fit => True);
                        Row_Y := Saturating_Add (Row_Y, Line_Height);
                     end if;
                     if Row_Y < Content_End_Y then
                        Add_Overlay_Text
                          (QL.Content_X, Row_Y, QL.Content_Width,
                           Natural'Min (Line_Height, Content_End_Y - Row_Y),
                           Size_Value, Muted_Text_Color, Fit => True);
                     end if;
                  end;
            end case;

            Draw_Close_Button (QL.X, QL.Y, QL.Width, QL.Height, Overlay => True);
         end;
      end if;

      if Snapshot.Label_Picker_Open then
         declare
            Picker  : constant Label_Picker_Layout :=
              Calculate_Label_Picker_Layout (Layout, Line_Height);
            Margin  : constant Natural := Natural'Max (Command_Palette_Padding, Line_Height / 2);
            Title_X : constant Natural := Saturating_Add (Picker.X, Margin);
            Title_Y : constant Natural := Saturating_Add (Picker.Y, Natural'Max (4, Line_Height / 4));
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
            Add_Overlay_Rect
              (Picker.X, Picker.Y, Picker.Width, Natural'Min (3, Picker.Height), Selection_Color);
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
                  if Highlighted and then Swatch.Width > 4 and then Swatch.Height > 4 then
                     --  A second inset ring so the keyboard highlight reads
                     --  distinctly from a plain mouse hover.
                     Add_Overlay_Border
                       (Swatch.X + 2, Swatch.Y + 2, Swatch.Width - 4, Swatch.Height - 4,
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
            Row_Count : constant Natural := 5;
            Row_H     : constant Natural :=
              Saturating_Add (Line_Height, Saturating_Multiply (Guikit.Layout.Bottom_Bar_Padding, 2));
            Rows_H    : constant Natural := Saturating_Multiply (Row_H, Row_Count);
            Menu_H    : constant Natural :=
              Saturating_Add (Rows_H, Saturating_Multiply (Guikit.Layout.Sort_Menu_Padding, 2));
            Menu_X    : constant Natural := Bottom.Sort_Button_X;
            Menu_Y    : constant Natural := (if Bottom_Y > Menu_H then Bottom_Y - Menu_H else 0);
            --  The dropdown fits the widest field, not the (snug) sort button.
            Menu_W    : constant Natural :=
              Files.UI.Sort_Menu_Visible_Width
                (Width, Snapshot.Sort_Field, Line_Height);
            Rows_Y    : constant Natural := Saturating_Add (Menu_Y, Guikit.Layout.Sort_Menu_Padding);
            Row_X     : constant Natural := Saturating_Add (Menu_X, 1);
            Row_W     : constant Natural := (if Menu_W > 2 then Menu_W - 2 else 0);

            type Sort_Field_Array is array (Positive range <>) of Files.Model.Sort_Field;
            Fields : constant Sort_Field_Array :=
              [Files.Model.Sort_Name,
               Files.Model.Sort_Size,
               Files.Model.Sort_Type,
               Files.Model.Sort_Created,
               Files.Model.Sort_Changed];
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
                  Text_Padding        => Guikit.Layout.Input_Field_Padding,
                  Show_Alternate_Rows => False,
                  others              => <>);
            begin
               for Row in Fields'Range loop
                  declare
                     Field    : constant Files.Model.Sort_Field := Fields (Row);
                     Row_Y    : constant Natural :=
                       Saturating_Add (Rows_Y, Saturating_Multiply (Natural (Row - 1), Row_H));
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

               for Row in Fields'Range loop
                  declare
                     Field : constant Files.Model.Sort_Field := Fields (Row);
                     Row_Y : constant Natural :=
                       Saturating_Add (Rows_Y, Saturating_Multiply (Natural (Row - 1), Row_H));
                     Selected : constant Boolean := Field = Snapshot.Sort_Field;
                     Label : constant UString :=
                       To_Unbounded_String
                         (Sort_Field_Label (Field)
                          & (if Selected then " " & Direction_Text else ""));
                  begin
                     if Row > Fields'First then
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
