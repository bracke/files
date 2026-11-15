separate (Files.Rendering.Layouts)
   function Main_Content_Rect (Layout : Layout_Metrics) return Content_Rectangle is
      Padding : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding (Layout), 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding (Layout), 2)
         then Main_Content_Padding (Layout)
         else 0);
   begin
      return
        (X      => Guikit.Layout.Saturating_Add (Layout.Main_X, Padding),
         Y      => Guikit.Layout.Saturating_Add (Layout.Main_Y, Padding),
         Width  => (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
                    then Layout.Main_Width - Saturating_Multiply (Padding, 2)
                    else Layout.Main_Width),
         Height => (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
                    then Layout.Main_Height - Saturating_Multiply (Padding, 2)
                    else Layout.Main_Height));
   end Main_Content_Rect;
