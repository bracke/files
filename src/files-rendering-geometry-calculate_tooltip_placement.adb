separate (Files.Rendering.Geometry)
   function Calculate_Tooltip_Placement
     (Frame_Width, Frame_Height, Pointer_X, Pointer_Y, Box_Width, Box_Height : Natural; Line_Height : Positive)
      return Tooltip_Placement
   is
      use Guikit.Layout;

      Margin         : constant Natural := Tooltip_Margin (Line_Height);
      Horizontal_Gap : constant Natural := Scaled (12, Line_Height);
      Vertical_Gap   : constant Natural := Scaled (18, Line_Height);

      function Fits_Right return Boolean is
        (Frame_Width > Margin
         and then Pointer_X <= Natural'Last - Horizontal_Gap
         and then Saturating_Add (Pointer_X, Horizontal_Gap) <= Natural'Last - Box_Width
         and then Saturating_Add (Saturating_Add (Pointer_X, Horizontal_Gap), Box_Width) <= Frame_Width - Margin);

      function Fits_Left return Boolean is
        (Pointer_X >= Saturating_Add (Saturating_Add (Box_Width, Horizontal_Gap), Margin));

      function Fits_Below return Boolean is
        (Frame_Height > Margin
         and then Pointer_Y <= Natural'Last - Vertical_Gap
         and then Saturating_Add (Pointer_Y, Vertical_Gap) <= Natural'Last - Box_Height
         and then Saturating_Add (Saturating_Add (Pointer_Y, Vertical_Gap), Box_Height) <= Frame_Height - Margin);

      function Fits_Above return Boolean is
        (Pointer_Y >= Saturating_Add (Saturating_Add (Box_Height, Vertical_Gap), Margin));
   begin
      return
        (X =>
           (if Fits_Right then Saturating_Add (Pointer_X, Horizontal_Gap)
            elsif Fits_Left then Pointer_X - Box_Width - Horizontal_Gap
            elsif Frame_Width > Saturating_Add (Box_Width, Margin)
            then Natural'Min (Pointer_X, Frame_Width - Box_Width - Margin)
            else 0),
         Y =>
           (if Fits_Below then Saturating_Add (Pointer_Y, Vertical_Gap)
            elsif Fits_Above then Pointer_Y - Box_Height - Vertical_Gap
            elsif Frame_Height > Saturating_Add (Box_Height, Margin)
            then Natural'Min (Pointer_Y, Frame_Height - Box_Height - Margin)
            else 0));
   end Calculate_Tooltip_Placement;
