separate (Files.Rendering.Layouts)
   function Path_Field_Text_Region
     (Toolbar     : Guikit.Layout.Toolbar_Layout;
      Width       : Natural;
      Line_Height : Positive)
      return Field_Text_Region
   is
      Padding      : constant Natural := Field_Padding (Line_Height);
      Margin       : constant Natural := Toolbar_Field_Margin (Line_Height);
      Field_X      : constant Natural := Guikit.Layout.Saturating_Add (Toolbar.Middle_X, Margin);
      Field_W      : constant Natural :=
        (if Toolbar.Middle_Width > Guikit.Layout.Saturating_Multiply (Margin, 2)
         then Toolbar.Middle_Width - Guikit.Layout.Saturating_Multiply (Margin, 2)
         else 0);
      Star_Reserve : constant Natural := Path_Bar_Content_Offset (Width, Line_Height);
      Used         : constant Natural := Guikit.Layout.Saturating_Add (
        Guikit.Layout.Saturating_Multiply (Padding, 2), Star_Reserve);
   begin
      return
        (X           => Guikit.Layout.Saturating_Add (Guikit.Layout.Saturating_Add (Field_X, Padding), Star_Reserve),
         Width       => (if Field_W > Used then Field_W - Used else 0),
         Field_X     => Field_X,
         Field_Width => Field_W);
   end Path_Field_Text_Region;
