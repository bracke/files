separate (Files.Rendering.Build_Frame_Commands.Draw_Bottom_Bar)
   --  The free-space field right of the divider: the free or used space as
   --  text, or as a meter in bar mode. Clicking it toggles the display.
   --
   --  @param Divider_X     Left edge of the field's interactive region.
   --  @param Free_X        Left edge of the field's text.
   --  @param Free_Field_W  Width of the field's text.
   --  @param Free_Region_W Width of the field's interactive region.
   procedure Draw_Free_Space (Divider_X, Free_X, Free_Field_W, Free_Region_W : Natural) is
      Pad           : constant Natural := Files.Rendering.Layouts.Status_Field_Padding (Line_Height);
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
           Is_Hovered (Free_Region_X, Bottom_Y, Free_Region_W, Layout.Bottom_Bar_Height),
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
                (Guikit.Layout.Scaled (8, Line_Height), Guikit.Layout.Saturating_Multiply (Line_Height, 2) / 3);
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
            To_Unbounded_String (Free_Space_Label (Snapshot)),
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
   end Draw_Free_Space;
