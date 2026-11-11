separate (Files.Rendering)
function Calculate_Label_Picker_Layout
  (Layout      : Layout_Metrics;
   Line_Height : Positive)
   return Label_Picker_Layout
is
   Count           : constant Positive := Files.Types.Swatch_Count;
   Padding         : constant Natural := Natural'Max (Command_Palette_Padding (Line_Height), Line_Height / 2);
   Desired_Gap     : constant Natural := Natural'Max (Guikit.Layout.Scaled (4, Line_Height), Line_Height / 4);
   --  A compact centered panel: a single row of square swatches under a
   --  one-line title band. The preferred swatch edge tracks the line height;
   --  narrow/short windows shrink the row below that preference.
   Desired_Swatch : constant Natural := Saturating_Multiply (Line_Height, 2);
   Desired_Title_H : constant Natural := Saturating_Add (Line_Height, Padding);
   Desired_Row_W : constant Natural :=
     Saturating_Add
       (Saturating_Multiply (Desired_Swatch, Count),
        Saturating_Multiply (Desired_Gap, Count - 1));
   Panel_W  : constant Natural :=
     Natural'Min
       (Layout.Width,
        Saturating_Add (Desired_Row_W, Saturating_Multiply (Padding, 2)));
   Panel_H  : constant Natural :=
     Natural'Min
       (Layout.Height,
        Saturating_Add
          (Desired_Title_H,
           Saturating_Add (Desired_Swatch, Saturating_Multiply (Padding, 2))));
   Panel_X  : constant Natural :=
     Centered (Layout.Width, Panel_W);
   Panel_Y  : constant Natural :=
     Centered (Layout.Height, Panel_H);
   Horizontal_Padding : constant Natural := Natural'Min (Padding, Panel_W / 2);
   Inner_W            : constant Natural :=
     Panel_W - Saturating_Multiply (Horizontal_Padding, 2);
   --  Keep at least one pixel per swatch before assigning inter-swatch gaps.
   --  On extremely narrow panels the gaps collapse completely.
   Gap : constant Natural :=
     (if Count > 1 and then Inner_W > Count
      then Natural'Min (Desired_Gap, (Inner_W - Count) / (Count - 1))
      else 0);
   Gaps_W : constant Natural := Saturating_Multiply (Gap, Count - 1);
   Horizontal_Swatch : constant Natural :=
     (if Inner_W > Gaps_W
      then Natural'Min (Desired_Swatch, (Inner_W - Gaps_W) / Count)
      else 0);
   Title_H     : constant Natural := Natural'Min (Desired_Title_H, Panel_H);
   Remaining_H : constant Natural := Panel_H - Title_H;
   Swatch      : constant Natural := Natural'Min (Horizontal_Swatch, Remaining_H);
   Row_W            : constant Natural :=
     Saturating_Add
       (Saturating_Multiply (Swatch, Count), Gaps_W);
   Row_X            : constant Natural :=
     Saturating_Add (Panel_X, (Panel_W - Row_W) / 2);
   Row_Y            : constant Natural := Saturating_Add (Panel_Y, Title_H);
   Result   : Label_Picker_Layout;
begin
   Result.X           := Panel_X;
   Result.Y           := Panel_Y;
   Result.Width       := Panel_W;
   Result.Height      := Panel_H;
   Result.Swatch_Size := Swatch;
   Result.Visible     := Panel_W > 0 and then Panel_H > 0;
   for Index in Result.Swatches'Range loop
      Result.Swatches (Index) :=
        (X      => Saturating_Add
                     (Row_X,
                      Saturating_Multiply (Index - 1, Saturating_Add (Swatch, Gap))),
         Y      => Row_Y,
         Width  => Swatch,
         Height => Swatch);
   end loop;
   return Result;
end Calculate_Label_Picker_Layout;
