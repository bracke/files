separate (Files.Rendering)
   function Calculate_Conflict_Dialog_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Conflict_Dialog_Layout
   is
      pragma Unreferenced (Snapshot);
      Pad        : constant Natural := 12;
      Max_Width  : constant Natural := Saturating_Multiply (Line_Height, 22);
      Margin     : constant Natural := Saturating_Multiply (Line_Height, 2);
      Inner_W    : constant Natural :=
        (if Layout.Width > Saturating_Multiply (Margin, 2)
         then Layout.Width - Saturating_Multiply (Margin, 2)
         else Layout.Width);
      Width      : constant Natural := Natural'Min (Max_Width, Inner_W);
      Message_H  : constant Natural := Saturating_Multiply (Line_Height, 2);
      Apply_H    : constant Natural := Line_Height;
      Button_H   : constant Natural := Saturating_Add (Line_Height, Pad);
      Height     : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Pad, 4),
           Saturating_Add (Message_H, Saturating_Add (Apply_H, Button_H)));
      X          : constant Natural := (if Layout.Width > Width then (Layout.Width - Width) / 2 else 0);
      Y          : constant Natural := (if Layout.Height > Height then (Layout.Height - Height) / 2 else 0);
      Button_Y   : constant Natural :=
        (if Height > Saturating_Add (Pad, Button_H)
         then Saturating_Add (Y, Height - Pad - Button_H)
         else Y);
      Apply_Y    : constant Natural :=
        (if Button_Y > Saturating_Add (Pad, Apply_H) then Button_Y - Pad - Apply_H else Button_Y);
      Inner_Buttons : constant Natural :=
        (if Width > Saturating_Multiply (Pad, 5) then Width - Saturating_Multiply (Pad, 5) else 0);
      Button_W   : constant Natural := Inner_Buttons / 4;
      Apply_W    : constant Natural :=
        (if Width > Saturating_Multiply (Pad, 2) then Width - Saturating_Multiply (Pad, 2) else Width);
   begin
      return
        (X             => X,
         Y             => Y,
         Width         => Width,
         Height        => Height,
         Apply_X       => Saturating_Add (X, Pad),
         Apply_Y       => Apply_Y,
         Apply_Width   => Apply_W,
         Apply_Height  => Apply_H,
         Button_Y      => Button_Y,
         Button_Height => Button_H,
         Replace_X     => Saturating_Add (X, Pad),
         Skip_X        => Saturating_Add (X, Saturating_Add (Saturating_Multiply (Pad, 2), Button_W)),
         Rename_X      =>
           Saturating_Add
             (X, Saturating_Add (Saturating_Multiply (Pad, 3), Saturating_Multiply (Button_W, 2))),
         Cancel_X      =>
           Saturating_Add
             (X, Saturating_Add (Saturating_Multiply (Pad, 4), Saturating_Multiply (Button_W, 3))),
         Button_Width  => Button_W);
   end Calculate_Conflict_Dialog_Layout;
