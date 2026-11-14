separate (Files.Rendering.Layouts)
   function Calculate_Bottom_Bar_Layout
     (Width       : Natural;
      Sort_Field  : Files.Types.Sort_Field;
      Line_Height : Positive)
      return Guikit.Layout.Bottom_Bar_Layout
   is
      Cell_W : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);

      --  Size the sort button to the active field's label only (plus the
      --  direction indicator), not the widest field, so it is never wider than
      --  the text it shows.
      Sort_Label_W : constant Natural :=
        Guikit.Layout.Label_Pixel_Width
          (Files.Localization.Text (Files.Commands.Sort_Label_Key (Sort_Field))
           & " "
           & Files.Localization.Text ("sort.direction.ascending"),
           Cell_W);
   begin
      return
        Guikit.Layout.Calculate_Bottom_Bar_Layout
          (Width               => Width,
           Small_Label_Width   =>
             Guikit.Layout.Label_Pixel_Width (Files.Localization.Text ("command.view.small.short"), Cell_W),
           Large_Label_Width   =>
             Guikit.Layout.Label_Pixel_Width (Files.Localization.Text ("command.view.large.short"), Cell_W),
           Details_Label_Width =>
             Guikit.Layout.Label_Pixel_Width (Files.Localization.Text ("command.view.details.short"), Cell_W),
           Sort_Label_Width    => Sort_Label_W,
           Info_Label_Width    =>
             Guikit.Layout.Label_Pixel_Width (Files.Localization.Text ("command.info.toggle.short"), Cell_W),
           Line_Height         => Line_Height);
   end Calculate_Bottom_Bar_Layout;
