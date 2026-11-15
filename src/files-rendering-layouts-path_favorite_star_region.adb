separate (Files.Rendering.Layouts)
   function Path_Favorite_Star_Region
     (Width       : Natural;
      Line_Height : Positive)
      return Path_Favorite_Star_Bounds
   is
      Toolbar      : constant Guikit.Layout.Toolbar_Layout :=
        Guikit.Layout.Calculate_Toolbar_Layout (Width, Line_Height);
      Field_Margin : constant Natural := Toolbar_Field_Margin (Line_Height);
      Path_X       : constant Natural := Guikit.Layout.Saturating_Add (Toolbar.Middle_X, Field_Margin);
      Pad          : constant Natural := Field_Padding (Line_Height);
      --  Box for the drawn favourite star (a filled/outline vector shape); a
      --  near-line-height square so the star reads clearly at the input height.
      Star_W       : constant Positive := Line_Height;
   begin
      if Toolbar.Middle_Width
        <= Guikit.Layout.Saturating_Add
             (Saturating_Multiply (Field_Margin, 2), Guikit.Layout.Saturating_Add (Star_W, Pad))
      then
         return (others => <>);
      end if;
      return
        (X       => Guikit.Layout.Saturating_Add (Path_X, Pad),
         Y       => Guikit.Layout.Toolbar_Input_Y (Line_Height),
         Width   => Star_W,
         Height  => Guikit.Layout.Toolbar_Input_Height (Line_Height),
         Visible => True);
   end Path_Favorite_Star_Region;
