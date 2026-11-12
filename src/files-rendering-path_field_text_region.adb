separate (Files.Rendering)
   function Path_Field_Text_Region
     (Toolbar     : Guikit.Layout.Toolbar_Layout;
      Width       : Natural;
      Line_Height : Positive)
      return Field_Text_Region
   is
      Padding      : constant Natural := Files.UI.Field_Padding (Line_Height);
      Field_X      : constant Natural := Saturating_Add (Toolbar.Middle_X, Toolbar_Field_Margin);
      Field_W      : constant Natural :=
        (if Toolbar.Middle_Width > Saturating_Multiply (Toolbar_Field_Margin, 2)
         then Toolbar.Middle_Width - Saturating_Multiply (Toolbar_Field_Margin, 2)
         else 0);
      Star_Reserve : constant Natural := Path_Bar_Content_Offset (Width, Line_Height);
      Used         : constant Natural := Saturating_Add (Saturating_Multiply (Padding, 2), Star_Reserve);
   begin
      return
        (X           => Saturating_Add (Saturating_Add (Field_X, Padding), Star_Reserve),
         Width       => (if Field_W > Used then Field_W - Used else 0),
         Field_X     => Field_X,
         Field_Width => Field_W);
   end Path_Field_Text_Region;
