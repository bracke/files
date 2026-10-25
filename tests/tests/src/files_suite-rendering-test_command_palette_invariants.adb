separate (Files_Suite.Rendering)
   procedure Test_Command_Palette_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
      Palette  : constant Command_Palette_Layout := Calculate_Command_Palette_Layout (Layout, 20);
   begin
      Assert (Palette.Width > 0 and then Palette.Height > 0, "the palette has a positive size");
      Assert (Palette.X + Palette.Width <= Layout.Width, "the palette fits within the window width");
      Assert (Palette.Y + Palette.Height <= Layout.Height, "the palette fits within the window height");
      Assert (Palette.Search_Y >= Palette.Y, "the search field is inside the palette");
      Assert (Palette.Results_Y >= Palette.Search_Y, "results are placed below the search field");
      Assert
        (Palette.Search_X >= Palette.X
         and then Palette.Search_X + Palette.Search_Width <= Palette.X + Palette.Width,
         "the search field stays within the palette width");
   end Test_Command_Palette_Invariants;
