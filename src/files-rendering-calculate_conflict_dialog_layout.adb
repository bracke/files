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
      Desired_Message_H : constant Natural := Saturating_Multiply (Line_Height, 2);
      Desired_Apply_H   : constant Natural := Line_Height;
      Desired_Button_H  : constant Natural := Saturating_Add (Line_Height, Pad);
      Desired_Height    : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Pad, 4),
           Saturating_Add
             (Desired_Message_H,
              Saturating_Add (Desired_Apply_H, Desired_Button_H)));
      Height     : constant Natural := Natural'Min (Layout.Height, Desired_Height);
      X          : constant Natural := (if Layout.Width > Width then (Layout.Width - Width) / 2 else 0);
      Y          : constant Natural := (if Layout.Height > Height then (Layout.Height - Height) / 2 else 0);
      Base_Content_H : constant Natural :=
        Saturating_Add
          (Desired_Message_H,
           Saturating_Add (Desired_Apply_H, Desired_Button_H));
      Gap : constant Natural :=
        (if Height > Base_Content_H
         then Natural'Min (Pad, (Height - Base_Content_H) / 4)
         else 0);
      Button_H : constant Natural :=
        (if Height >= Base_Content_H
         then Desired_Button_H
         else Natural'Min (Desired_Button_H, Height / 3));
      Apply_H : constant Natural :=
        (if Height >= Base_Content_H
         then Desired_Apply_H
         else Natural'Min (Desired_Apply_H, (Height - Button_H) / 2));
      Message_H : constant Natural :=
        (if Height >= Base_Content_H
         then Desired_Message_H
         else Height - Button_H - Apply_H);
      Message_Y : constant Natural := Saturating_Add (Y, Gap);
      Apply_Y   : constant Natural :=
        Saturating_Add (Message_Y, Saturating_Add (Message_H, Gap));
      Button_Y  : constant Natural :=
        Saturating_Add (Apply_Y, Saturating_Add (Apply_H, Gap));
      Side_Pad : constant Natural := Natural'Min (Pad, Width / 2);
      Apply_W  : constant Natural := Width - Saturating_Multiply (Side_Pad, 2);
      Button_Gap : constant Natural :=
        (if Width > 4 then Natural'Min (Pad, (Width - 4) / 5) else 0);
      Inner_Buttons : constant Natural :=
        Width - Saturating_Multiply (Button_Gap, 5);
      Button_W   : constant Natural := Inner_Buttons / 4;
      Button_Step : constant Natural := Saturating_Add (Button_W, Button_Gap);
   begin
      return
        (X             => X,
         Y             => Y,
         Width         => Width,
         Height        => Height,
         Message_X      => Saturating_Add (X, Side_Pad),
         Message_Y      => Message_Y,
         Message_Width  => Apply_W,
         Message_Height => Message_H,
         Apply_X       => Saturating_Add (X, Side_Pad),
         Apply_Y       => Apply_Y,
         Apply_Width   => Apply_W,
         Apply_Height  => Apply_H,
         Button_Y      => Button_Y,
         Button_Height => Button_H,
         Replace_X     => Saturating_Add (X, Button_Gap),
         Skip_X        => Saturating_Add (X, Saturating_Add (Button_Gap, Button_Step)),
         Rename_X      =>
           Saturating_Add
             (X, Saturating_Add (Button_Gap, Saturating_Multiply (Button_Step, 2))),
         Cancel_X      =>
           Saturating_Add
             (X, Saturating_Add (Button_Gap, Saturating_Multiply (Button_Step, 3))),
         Button_Width  => Button_W);
   end Calculate_Conflict_Dialog_Layout;
