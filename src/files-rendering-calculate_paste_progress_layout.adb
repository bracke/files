separate (Files.Rendering)
   function Calculate_Paste_Progress_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Paste_Progress_Layout
   is
      pragma Unreferenced (Snapshot);
      Pad       : constant Natural := 12;
      Max_Width : constant Natural := Saturating_Multiply (Line_Height, 22);
      Margin    : constant Natural := Saturating_Multiply (Line_Height, 2);
      Inner_W   : constant Natural :=
        (if Layout.Width > Saturating_Multiply (Margin, 2)
         then Layout.Width - Saturating_Multiply (Margin, 2)
         else Layout.Width);
      Width     : constant Natural := Natural'Min (Max_Width, Inner_W);
      Message_H : constant Natural := Saturating_Multiply (Line_Height, 2);
      Bar_H     : constant Natural := Natural'Max (6, Line_Height / 2);
      Button_H  : constant Natural := Saturating_Add (Line_Height, Pad);
      Height    : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Pad, 5),
           Saturating_Add (Message_H, Saturating_Add (Bar_H, Button_H)));
      X         : constant Natural := (if Layout.Width > Width then (Layout.Width - Width) / 2 else 0);
      Y         : constant Natural := (if Layout.Height > Height then (Layout.Height - Height) / 2 else 0);
      Bar_W     : constant Natural :=
        (if Width > Saturating_Multiply (Pad, 2) then Width - Saturating_Multiply (Pad, 2) else Width);
      Bar_Y     : constant Natural :=
        Saturating_Add (Y, Saturating_Add (Message_H, Saturating_Multiply (Pad, 2)));
      Button_H2 : constant Natural := Button_H;
      Button_Y  : constant Natural :=
        (if Height > Saturating_Add (Pad, Button_H2)
         then Saturating_Add (Y, Height - Pad - Button_H2) else Y);
      Button_W  : constant Natural :=
        Natural'Min
          (Saturating_Multiply (Line_Height, 6),
           (if Width > Saturating_Multiply (Pad, 2) then Width - Saturating_Multiply (Pad, 2) else Width));
      Button_X  : constant Natural :=
        (if Width > Saturating_Add (Button_W, Pad) then Saturating_Add (X, Width - Pad - Button_W) else X);
   begin
      return
        (X             => X,
         Y             => Y,
         Width         => Width,
         Height        => Height,
         Bar_X         => Saturating_Add (X, Pad),
         Bar_Y         => Bar_Y,
         Bar_Width     => Bar_W,
         Bar_Height    => Bar_H,
         Cancel_X      => Button_X,
         Cancel_Y      => Button_Y,
         Cancel_Width  => Button_W,
         Cancel_Height => Button_H2);
   end Calculate_Paste_Progress_Layout;
