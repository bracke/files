separate (Files.Rendering)
   function Calculate_Paste_Progress_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Paste_Progress_Layout
   is
      Pad       : constant Natural := Files.UI.Dialog_Padding (Line_Height);
      Width      : constant Natural := Dialog_Box_Width (Layout, Line_Height);
      Desired_Message_H : constant Natural := Saturating_Multiply (Line_Height, 2);
      Desired_Bar_H     : constant Natural := Natural'Max (Guikit.Layout.Scaled (6, Line_Height), Line_Height / 2);
      Desired_Button_H  : constant Natural := Guikit.Layout.Saturating_Add (Line_Height, Pad);
      Desired_Height    : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Saturating_Multiply (Pad, 5),
           Guikit.Layout.Saturating_Add
             (Desired_Message_H,
              Guikit.Layout.Saturating_Add (Desired_Bar_H, Desired_Button_H)));
      Height    : constant Natural := Natural'Min (Layout.Height, Desired_Height);
      X         : constant Natural := Centered (Layout.Width, Width);
      Y         : constant Natural := Centered (Layout.Height, Height);
      Base_Content_H : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Desired_Message_H,
           Guikit.Layout.Saturating_Add (Desired_Bar_H, Desired_Button_H));
      Gap : constant Natural :=
        (if Height > Base_Content_H
         then Natural'Min (Pad, (Height - Base_Content_H) / 5)
         else 0);
      Button_H : constant Natural :=
        (if Height >= Base_Content_H
         then Desired_Button_H
         else Natural'Min (Desired_Button_H, Height / 3));
      Bar_H : constant Natural :=
        (if Height >= Base_Content_H
         then Desired_Bar_H
         else Natural'Min (Desired_Bar_H, (Height - Button_H) / 3));
      Message_H : constant Natural :=
        (if Height >= Base_Content_H
         then Desired_Message_H
         else Height - Button_H - Bar_H);
      Message_Y : constant Natural := Guikit.Layout.Saturating_Add (Y, Gap);
      Bar_Y     : constant Natural :=
        Guikit.Layout.Saturating_Add (Message_Y, Guikit.Layout.Saturating_Add (Message_H, Gap));
      Button_Y  : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Bar_Y, Guikit.Layout.Saturating_Add (Bar_H, Saturating_Multiply (Gap, 2)));
      Side_Pad  : constant Natural := Natural'Min (Pad, Width / 2);
      Bar_W     : constant Natural := Width - Saturating_Multiply (Side_Pad, 2);
      Button_W  : constant Natural :=
        Natural'Min
          (Saturating_Multiply (Line_Height, 6),
           Bar_W);
      Button_X  : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Guikit.Layout.Saturating_Add (X, Side_Pad), Bar_W - Button_W);
   begin
      return
        (X             => X,
         Y             => Y,
         Width         => Width,
         Height        => Height,
         Message_X      => Guikit.Layout.Saturating_Add (X, Side_Pad),
         Message_Y      => Message_Y,
         Message_Width  => Bar_W,
         Message_Height => Message_H,
         Bar_X         => Guikit.Layout.Saturating_Add (X, Side_Pad),
         Bar_Y         => Bar_Y,
         Bar_Width     => Bar_W,
         Bar_Height    => Bar_H,
         Cancel_X      => Button_X,
         Cancel_Y      => Button_Y,
         Cancel_Width  => Button_W,
         Cancel_Height => Button_H);
   end Calculate_Paste_Progress_Layout;
