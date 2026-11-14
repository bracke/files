separate (Files.Rendering.Build_Frame_Commands)
   --  The bottom bar: sort button, counts and hidden toggle, free space, info-pane toggle.
   procedure Draw_Bottom_Bar is
   begin
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
              Saturating_Multiply (Guikit.Utf8.Display_Units (Field_Label), Cell_W);
            --  Tighter than a full monospace space so the direction arrow sits
            --  close to the sort field it belongs to.
            Arrow_Gap   : constant Natural := Cell_W / 2;
            Arrow_W     : constant Natural :=
              Saturating_Multiply (Guikit.Utf8.Display_Units (Arrow_Text), Cell_W);
            --  Actual field + gap + arrow width drawn. The button is sized assuming
            --  a full space before the arrow, so it is a touch wider; centre the
            --  drawn content within the button rather than left-aligning it.
            Rendered_W  : constant Natural :=
              Guikit.Layout.Saturating_Add (Label_W, Guikit.Layout.Saturating_Add (Arrow_Gap, Arrow_W));
            Text_X0     : constant Natural :=
              Guikit.Layout.Saturating_Add
                (Bottom.Sort_Button_X,
                 (if Bottom.Sort_Button_Width > Rendered_W
                  then (Bottom.Sort_Button_Width - Rendered_W) / 2
                  else Files.UI.Field_Padding (Line_Height)));
            Content_W   : constant Natural :=
              (if Bottom.Sort_Button_Width > Saturating_Multiply (Files.UI.Field_Padding (Line_Height), 2)
               then Bottom.Sort_Button_Width - Saturating_Multiply (Files.UI.Field_Padding (Line_Height), 2)
               else 0);
            Arrow_X     : constant Natural :=
              Guikit.Layout.Saturating_Add (Text_X0, Guikit.Layout.Saturating_Add (Label_W, Arrow_Gap));
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
            if Content_W > Guikit.Layout.Saturating_Add (Label_W, Arrow_Gap) then
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
         Pad       : constant Natural := Files.UI.Status_Field_Padding (Line_Height);
         Cell_W    : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);
         Free_Text : constant String := Free_Space_Label (Snapshot);
         Free_W    : constant Natural := Free_Space_Label_Width (Snapshot, Line_Height);
         --  The counts/free split, shared with the click hit-test so the toggle's
         --  hover/press/tooltip area and the separate free-space field agree.
         Toggle_W, Divider_X, Free_X, Free_Field_W, Free_Region_W : Natural;
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
            Toggle_W, Divider_X, Free_X, Free_Field_W, Free_Region_W, Line_Height);
         declare
            Show_Free : constant Boolean := Free_Field_W > 0;
            Counts_W  : constant Natural := (if Toggle_W > 2 * Pad then Toggle_W - 2 * Pad else 0);
            Info_Text : constant UString := Bottom_Info_Text;
            --  When the labelled counts do not fit the available width, collapse
            --  to just the three numbers (hidden / visible / selected),
            --  slash-separated and label-less. The error line is never collapsed.
            Compact   : constant String :=
              Grouped_Natural_Text (Snapshot.Hidden_Count) & "/"
              & Grouped_Natural_Text (Snapshot.Visible_Count) & "/"
              & Grouped_Natural_Text (Snapshot.Selected_Count);
            Use_Compact : constant Boolean :=
              Length (Snapshot.Last_Error_Key) = 0
              and then Saturating_Multiply (Guikit.Utf8.Display_Units (To_String (Info_Text)), Cell_W) > Counts_W;
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
            Add_Button
              (Bottom.Info_X, Toggle_W,
               Selected => False,
               Hovered  =>
                 Has_Hover
                 and then Contains_Point
                   (Bottom.Info_X, Bottom_Y, Toggle_W, Layout.Bottom_Bar_Height, Hover_X, Hover_Y),
               Pressed  => Is_Pressed (Bottom.Info_X, Bottom_Y, Toggle_W, Layout.Bottom_Bar_Height),
               Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command));
            Add_Text
              (Guikit.Layout.Saturating_Add (Bottom.Info_X, Pad),
               Bottom_Content_Y,
               Counts_W,
               Bottom_Content_H,
               Status_Text,
               Counts_Color,
               Fit => True);
            if Show_Free then
               declare
                  --  The free field's interactive region: from the divider to the
                  --  right edge of the info area, as the click hit-test has it.
                  Free_Region_X : constant Natural := Divider_X;
               begin
                  --  Clicking the field toggles free/used space, so it gets the
                  --  same hover/press affordance as the neighbouring toggles.
                  Add_Button
                    (Free_Region_X, Free_Region_W,
                     Selected => False,
                     Hovered  =>
                       Has_Hover
                       and then Contains_Point
                         (Free_Region_X, Bottom_Y, Free_Region_W, Layout.Bottom_Bar_Height, Hover_X, Hover_Y),
                     Pressed  => Is_Pressed (Free_Region_X, Bottom_Y, Free_Region_W, Layout.Bottom_Bar_Height),
                     Enabled  =>
                       Snapshot.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command));
                  --  Span the full bar height (matching the button fills), not
                  --  just the inset content band, so the divider reaches top to
                  --  bottom.
                  Add_Rect
                    (Divider_X,
                     Guikit.Layout.Saturating_Add (Bottom_Y, 1),
                     1,
                     (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
                      else Layout.Bottom_Bar_Height),
                     Border_Color);
                  if Free_Space_Bar_Active (Snapshot) then
                     --  Bar mode: a scrollbar-like track whose blue core width is
                     --  the fraction of disk space used.
                     declare
                        Bar_H  : constant Natural :=
                          Natural'Max
                            (Guikit.Layout.Scaled (8, Line_Height), Saturating_Multiply (Line_Height, 2) / 3);
                        --  Centre the bar in the field's full height (the hover
                        --  rect band), not the smaller inset content band.
                        Bar_Y  : constant Natural :=
                          (if Info_Btn_H > Bar_H
                           then Guikit.Layout.Saturating_Add (Info_Btn_Y, (Info_Btn_H - Bar_H) / 2)
                           else Info_Btn_Y);
                        Bar_W  : constant Natural :=
                          (if Free_Field_W > Pad then Free_Field_W - Pad else 0);
                        --  Centre the bar in the field's interactive region so the
                        --  margins before and after it are equal.
                        Bar_X  : constant Natural :=
                          (if Free_Region_W > Bar_W
                           then Guikit.Layout.Saturating_Add (Free_Region_X, (Free_Region_W - Bar_W) / 2)
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
      declare
         --  The label's inset inside the toggle, scaled with the text.
         Inset : constant Natural := Guikit.Layout.Scaled (4, Line_Height);
      begin
         Add_Text
           (Guikit.Layout.Saturating_Add (Bottom.Info_Pane_X, Inset),
            Bottom_Content_Y,
            (if Bottom.Info_Pane_Width > 2 * Inset then Bottom.Info_Pane_Width - 2 * Inset else 0),
            Bottom_Content_H,
            Bottom_Command_Label (Files.Commands.Toggle_Info_Pane_Command),
            Command_Color (Files.Commands.Toggle_Info_Pane_Command),
            Fit => True);
      end;
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
   end Draw_Bottom_Bar;
