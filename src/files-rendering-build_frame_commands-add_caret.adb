separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Caret
     (Region  : Files.Rendering.Layouts.Field_Text_Region;
      Y       : Natural;
      Field_H : Natural;
      Caret_X : Natural)
   is
      --  Caret_X pixels from the text's own origin (padding and any star
      --  reserve already taken, as the click-to-caret mapping reads them),
      --  clamped inside the box.
      Raw_X   : constant Natural := Guikit.Layout.Saturating_Add (Region.X, Caret_X);
      Field_W : constant Natural := Region.Field_Width;
      Max_X   : constant Natural :=
        (if Field_W > 2 then Guikit.Layout.Saturating_Add (Region.Field_X, Field_W - 2) else Region.Field_X);
      --  The caret height tracks the font: a fixed fraction of the line
      --  height (so it scales linearly with the font size), clamped to the
      --  field, and centered vertically. Using Line_Height minus fixed
      --  insets under-scaled it (stubby at small fonts, near-full at large).
      Caret_H : constant Natural :=
        Natural'Min
          ((if Field_H > 2 then Field_H - 2 else Field_H),
           Positive'Max (1, Font_Box_Height (Line_Height)));
      --  Glyph ink sits in the lower part of its cell, so a geometrically
      --  centered caret reads as floating too high above the text. Nudge it
      --  down toward the baseline, clamped so it stays inside the field.
      Descent_Bias : constant Natural := Line_Height / 8;
      Caret_Y : constant Natural :=
        Natural'Min
          (Guikit.Layout.Saturating_Add
             (Y,
              Guikit.Layout.Saturating_Add
                (Centered (Field_H, Caret_H),
                 Descent_Bias)),
           (if Field_H > Caret_H then Guikit.Layout.Saturating_Add (Y, Field_H - Caret_H) else Y));
      Caret_W : constant Natural := Natural'Min (Field_Caret_Width, Field_W);
   begin
      if Field_W > 0 and then Caret_H > 4 then
         Guikit.Widgets.Draw_Caret
           (Rectangles  => Result.Rectangles,
            Clip_Width  => Layout.Width,
            Clip_Height => Layout.Height,
            X           => Natural'Min (Raw_X, Max_X),
            Y           => Caret_Y,
            Width       => Caret_W,
            Height      => Caret_H,
            Color       => Text_Color);
      end if;
   end Add_Caret;
