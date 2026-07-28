separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Caret
     (X       : Natural;
      Y       : Natural;
      Field_W : Natural;
      Field_H : Natural;
      Text    : UString;
      Cursor  : Natural)
   is
      Char_W : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Raw    : constant String := To_String (Text);
      Raw_X  : constant Natural :=
        Saturating_Add
          (Saturating_Add (X, Guikit.Layout.Input_Field_Padding),
           Saturating_Multiply
             (Files.UTF8.Display_Units_Before (Raw, Cursor), Char_W));
      Max_X  : constant Natural := (if Field_W > 2 then Saturating_Add (X, Field_W - 2) else X);
      --  The caret height tracks the font: a fixed fraction of the line
      --  height (so it scales linearly with the font size), clamped to the
      --  field, and centered vertically. Using Line_Height minus fixed
      --  insets under-scaled it (stubby at small fonts, near-full at large).
      Caret_H : constant Natural :=
        Natural'Min
          ((if Field_H > 2 then Field_H - 2 else Field_H),
           Positive'Max (1, Saturating_Multiply (Line_Height, 4) / 5));
      --  Glyph ink sits in the lower part of its cell, so a geometrically
      --  centered caret reads as floating too high above the text. Nudge it
      --  down toward the baseline, clamped so it stays inside the field.
      Descent_Bias : constant Natural := Line_Height / 8;
      Caret_Y : constant Natural :=
        Natural'Min
          (Saturating_Add
             (Y,
              Saturating_Add
                ((if Field_H > Caret_H then (Field_H - Caret_H) / 2 else 0),
                 Descent_Bias)),
           (if Field_H > Caret_H then Saturating_Add (Y, Field_H - Caret_H) else Y));
      Caret_W : constant Natural := Natural'Min (2, Field_W);
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
