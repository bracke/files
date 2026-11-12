separate (Files.Rendering)
   function Filter_Field_Text_Region
     (Toolbar     : Guikit.Layout.Toolbar_Layout;
      Line_Height : Positive)
      return Field_Text_Region
   is
      Padding : constant Natural := Files.UI.Field_Padding (Line_Height);
      Field_W : constant Natural :=
        Guikit.Layout.Filter_Input_Field_Width
          (Toolbar, Files.UI.Filter_Scope_Chip_Width (Line_Height), Line_Height);
   begin
      return
        (X     => Saturating_Add (Saturating_Add (Toolbar.Right_X, Toolbar_Field_Margin), Padding),
         Width =>
           (if Field_W > Saturating_Multiply (Padding, 2)
            then Field_W - Saturating_Multiply (Padding, 2)
            else 0));
   end Filter_Field_Text_Region;
