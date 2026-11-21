with Files.Preference_Types;
separate (Files.Rendering.Build_Frame_Commands.Draw_Popups)
   --  The label picker: a titled panel of colour swatches, the keyboard
   --  highlight ringed twice so it reads apart from a mouse hover.
   procedure Draw_Label_Picker is
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
            Label   : constant Files.Preference_Types.Color_Label := Files.UI_Types.Label_For_Swatch (Index);
            Hovered : constant Boolean :=
              Is_Hovered (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height);
            Highlighted : constant Boolean := Index = Snapshot.Label_Picker_Highlight;
            Name    : constant UString :=
              Localized
                ((case Label is
                    when Files.Preference_Types.No_Label => "label.color.none",
                    when Files.Preference_Types.Red      => "label.color.red",
                    when Files.Preference_Types.Orange   => "label.color.orange",
                    when Files.Preference_Types.Yellow   => "label.color.yellow",
                    when Files.Preference_Types.Green    => "label.color.green",
                    when Files.Preference_Types.Blue     => "label.color.blue",
                    when Files.Preference_Types.Purple   => "label.color.purple",
                    when Files.Preference_Types.Gray     => "label.color.gray"));
         begin
            if Label = Files.Preference_Types.No_Label then
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
   end Draw_Label_Picker;
