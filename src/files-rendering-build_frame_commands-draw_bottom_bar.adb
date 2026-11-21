separate (Files.Rendering.Build_Frame_Commands)
   --  The bottom bar: view-mode switcher, sort button, counts and hidden
   --  toggle, free space, info-pane toggle.
   procedure Draw_Bottom_Bar is
      --  Fill the whole button height (matching the neighbouring bottom-bar
      --  controls and this control's own full-height hit region), not just
      --  the padding-inset content box, so hover/press has no uncovered
      --  stripe at the bottom.
      Info_Btn_Y : constant Natural :=
        (if Layout.Bottom_Bar_Height >= 1 then Bottom_Y + 1 else Bottom_Y);
      Info_Btn_H : constant Natural :=
        (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
         else Layout.Bottom_Bar_Height);

      procedure Draw_View_Switcher is separate;
      procedure Draw_Sort_Button is separate;
      procedure Draw_Free_Space (Divider_X, Free_X, Free_Field_W, Free_Region_W : Natural) is separate;
      procedure Draw_Status_Counts is separate;
      procedure Draw_Info_Toggle is separate;
   begin
      Draw_View_Switcher;
      Draw_Sort_Button;
      Draw_Status_Counts;
      Draw_Info_Toggle;

      --  The dividers between the sort button, the counts, the free space
      --  and the info-pane toggle, over the controls' fills.
      if Layout.Bottom_Bar_Height > 0 then
         if Bottom.Sort_Button_X > 0 and then Bottom.Sort_Button_Width > 0 then
            Add_Rect (Bottom.Sort_Button_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
         end if;
         if Bottom.Info_X > 0 then
            Add_Rect (Bottom.Info_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
         end if;
         if Bottom.Info_Pane_X > 0 then
            Add_Rect (Bottom.Info_Pane_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
         end if;
      end if;
   end Draw_Bottom_Bar;
