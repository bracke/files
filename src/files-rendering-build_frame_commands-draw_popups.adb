separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Popups is
      --  The chrome of a centered, titled modal panel (Quick Look, the label
      --  picker): the modal chrome on the pane colour, the accent band along
      --  its top, its title and close button.
      procedure Draw_Titled_Panel
        (X, Y, W, H                : Natural;
         Title_X, Title_Y, Title_W : Natural;
         Close_Button              : Close_Button_Layout;
         Title                     : UString;
         Name                      : UString;
         Description               : UString := Null_Unbounded_String)
      is
         Accent_H : constant Natural := Natural'Min (Guikit.Layout.Scaled (3, Line_Height), H);
      begin
         Draw_Modal_Chrome (X, Y, W, H, Pane_Color, Role_Dialog, Name, Description);
         Add_Overlay_Rect (X, Y, W, Accent_H, Selection_Color);
         Add_Overlay_Text (Title_X, Title_Y, Title_W, Line_Height, Title, Fit => True);
         Draw_Close_Button (Close_Button, Overlay => True);
      end Draw_Titled_Panel;

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
            --  The keyboard highlight's second ring sits this far inside a swatch.
            Ring_Inset : constant Natural := Guikit.Layout.Scaled (2, Line_Height);
         begin
            --  The picker consumes all background input until a color is
            --  chosen or it is dismissed.
            Draw_Titled_Panel
              (Picker.X, Picker.Y, Picker.Width, Picker.Height,
               Picker.Title_X, Picker.Title_Y, Picker.Title_W, Picker.Close_Button,
               Title => Localized ("label_picker.title"),
               Name  => Localized ("accessibility.label_picker"));

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
         end;
      end if;

      --  Shown where the click hit-test finds its rows: a menu laid out with
      --  no width (no sort button) is neither drawn nor hit.
      if Snapshot.Sort_Menu_Open then
         declare
            Menu      : constant Files.Rendering.Layouts.Sort_Menu_Layout :=
              Files.Rendering.Layouts.Calculate_Sort_Menu_Layout (Width, Height, Snapshot.Sort_Field, Line_Height);
         begin
            if Menu.Width > 0 then
               declare
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
                  Draw_Modal_Chrome
                    (Menu_X, Menu_Y, Menu_W, Menu_H, Overlay_Color, Role_List, Localized ("command.sort.menu"));

                  declare
                     --  Row backgrounds and label text are the shared list geometry --
                     --  delegate them to Guikit.List_Panel. The chrome, 1px inter-row
                     --  separators and the richer accessibility stay here. The sort menu
                     --  has no selected accent bar, so each row's accent is set to the
                     --  selection colour, which renders Draw_Palette_Row's accent
                     --  invisible against a selected row's background.
                     type Sort_Row is record
                        Field    : Files.Types.Sort_Field;
                        Y        : Natural;
                        Selected : Boolean;
                        Enabled  : Boolean;
                        Label    : UString;
                     end record;
                     --  Each row worked out once, for its fill and then for its
                     --  separator and accessibility node drawn over the fills.
                     Rows : array (1 .. Menu.Row_Count) of Sort_Row;
                     List_Rows    : Guikit.List_Panel.List_Panel_Row_Vectors.Vector;
                     Discard_A11y : Guikit.Draw.Accessibility_Node_Vectors.Vector;
                     Config : constant Guikit.List_Panel.List_Panel_Configuration :=
                       (Line_Height         => Line_Height,
                        Text_Padding        => Files.Rendering.Layouts.Field_Padding (Line_Height),
                        Show_Alternate_Rows => False,
                        others              => <>);
                  begin
                     for Row in Rows'Range loop
                        declare
                           Field    : constant Files.Types.Sort_Field :=
                             Files.Rendering.Layouts.Sort_Menu_Row_Field (Row);
                           Selected : constant Boolean := Field = Snapshot.Sort_Field;
                        begin
                           Rows (Row) :=
                             (Field    => Field,
                              Y        => Files.Rendering.Layouts.Sort_Menu_Row_Top (Menu, Row),
                              Selected => Selected,
                              Enabled  => Snapshot.Command_Enabled (Sort_Field_Command (Field)),
                              Label    =>
                                To_Unbounded_String
                                  (Sort_Field_Label (Field)
                                   & (if Selected then " " & Direction_Text (Snapshot.Sort_Ascending) else "")));
                        end;
                     end loop;

                     for Row in Rows'Range loop
                        declare
                           This        : Sort_Row renames Rows (Row);
                           Hovered     : constant Boolean :=
                             Has_Hover and then Contains_Point (Menu_X, This.Y, Menu_W, Row_H, Hover_X, Hover_Y);
                           Highlighted : constant Boolean := Row = Snapshot.Sort_Menu_Highlight;
                           Pressed     : constant Boolean := Is_Pressed (Menu_X, This.Y, Menu_W, Row_H);
                        begin
                           List_Rows.Append
                             (Guikit.List_Panel.List_Panel_Row'
                                (Label            => This.Label,
                                 Selected         => This.Selected,
                                 Enabled          => This.Enabled,
                                 Label_Color      => (if This.Enabled then Text_Color else Disabled_Text_Color),
                                 Accent_Color     => Selection_Color,
                                 Has_Background   => not This.Selected,
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

                     for Row in Rows'Range loop
                        if Row > Rows'First then
                           Add_Overlay_Rect (Row_X, Rows (Row).Y, Row_W, 1, Border_Color);
                        end if;
                        Add_Accessibility_Node
                          (Role_List_Item,
                           Menu_X,
                           Rows (Row).Y,
                           Menu_W,
                           Row_H,
                           Rows (Row).Label,
                           Localized (Files.Commands.Description_Key (Sort_Field_Command (Rows (Row).Field))),
                           Enabled  => Rows (Row).Enabled,
                           Selected => Rows (Row).Selected);
                     end loop;
                  end;
               end;
            end if;
         end;
      end if;
   end Draw_Popups;
