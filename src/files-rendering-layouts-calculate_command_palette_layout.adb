separate (Files.Rendering.Layouts)
   function Calculate_Command_Palette_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Command_Palette_Layout is
   begin
      --  The palette always carries a title, so reserve the title band the
      --  component renders, or clicks on results would be offset from the
      --  drawn rows.
      return Guikit.Layout.Calculate_Palette_Layout
        (Command_X      => Layout.Command_X,
         Command_Y      => Layout.Command_Y,
         Command_Width  => Layout.Command_Width,
         Command_Height => Layout.Command_Height,
         Line_Height    => Line_Height,
         Title_Height   => Guikit.Layout.Palette_Title_Height (Line_Height));
   end Calculate_Command_Palette_Layout;
