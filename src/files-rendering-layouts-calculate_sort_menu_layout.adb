separate (Files.Rendering.Layouts)
   function Calculate_Sort_Menu_Layout
     (Width       : Natural;
      Height      : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive)
      return Sort_Menu_Layout
   is
      Bottom    : constant Guikit.Layout.Bottom_Bar_Layout :=
        Calculate_Bottom_Bar_Layout (Width, Sort_Field, Line_Height);
      Row_Count : constant Natural := Files.Types.Sort_Menu_Rows;
      --  Each row is as tall as the bottom bar itself.
      Row_H     : constant Natural := Bottom_Bar_Height (Line_Height);
      Menu_Pad  : constant Natural := Guikit.Layout.Scaled (Guikit.Layout.Sort_Menu_Padding, Line_Height);
      Menu_H    : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Guikit.Layout.Saturating_Multiply (Row_H, Row_Count), Guikit.Layout.Saturating_Multiply (Menu_Pad, 2));
      Bottom_Y  : constant Natural := Bottom_Bar_Y (Height, Line_Height);
      Menu_Y    : constant Natural := (if Bottom_Y > Menu_H then Bottom_Y - Menu_H else 0);
   begin
      return
        (X          => Bottom.Sort_Button_X,
         Y          => Menu_Y,
         --  The dropdown is as wide as the widest field, not the (snug) sort
         --  button, clipped at the window's right edge.
         Width      =>
           (if Bottom.Sort_Button_Width = 0 or else Bottom.Sort_Button_X >= Width then 0
            else Natural'Min (Sort_Menu_Width (Line_Height), Width - Bottom.Sort_Button_X)),
         Height     => Menu_H,
         Rows_Y     => Guikit.Layout.Saturating_Add (Menu_Y, Menu_Pad),
         Row_Height => Row_H,
         Row_Count  => Row_Count);
   end Calculate_Sort_Menu_Layout;
