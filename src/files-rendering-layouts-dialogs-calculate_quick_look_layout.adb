separate (Files.Rendering.Layouts.Dialogs)
   function Calculate_Quick_Look_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Quick_Look_Layout
   is
      Padding   : constant Natural := Titled_Panel_Padding (Line_Height);
      --  A large centered panel: roughly three quarters of the window, with a
      --  sensible floor so it stays usable in tiny windows.
      Panel_W   : constant Natural :=
        Natural'Min (Layout.Width, Natural'Max (Saturating_Multiply (Line_Height, 16),
                                                Bounded_Product_Divide (Layout.Width, 3, 4)));
      Panel_H   : constant Natural :=
        Natural'Min (Layout.Height, Natural'Max (Saturating_Multiply (Line_Height, 12),
                                                 Bounded_Product_Divide (Layout.Height, 3, 4)));
      Panel_X   : constant Natural :=
        Centered (Layout.Width, Panel_W);
      Panel_Y   : constant Natural :=
        Centered (Layout.Height, Panel_H);
      --  The title band reserves one line height plus padding at the top.
      Desired_Title_H : constant Natural := Guikit.Layout.Saturating_Add (Line_Height, Padding);
      Title_H   : constant Natural := Natural'Min (Desired_Title_H, Panel_H);
      Horizontal_Padding : constant Natural := Natural'Min (Padding, Panel_W / 2);
      Remaining_H : constant Natural := Panel_H - Title_H;
      Bottom_Padding : constant Natural := Natural'Min (Padding, Remaining_H);
      Content_X : constant Natural := Guikit.Layout.Saturating_Add (Panel_X, Horizontal_Padding);
      Content_Y : constant Natural := Guikit.Layout.Saturating_Add (Panel_Y, Title_H);
      Used_W    : constant Natural := Saturating_Multiply (Horizontal_Padding, 2);
   begin
      return Result : Quick_Look_Layout :=
        (X              => Panel_X,
         Y              => Panel_Y,
         Width          => Panel_W,
         Height         => Panel_H,
         Content_X      => Content_X,
         Content_Y      => Content_Y,
         Content_Width  => Panel_W - Used_W,
         Content_Height => Remaining_H - Bottom_Padding,
         Close_Button   => Panel_Close_Button (Panel_X, Panel_Y, Panel_W, Panel_H, Line_Height),
         others         => 0)
      do
         Titled_Panel_Title (Panel_X, Panel_Y, Panel_W, Line_Height, Result.Title_X, Result.Title_Y, Result.Title_W);
      end return;
   end Calculate_Quick_Look_Layout;
