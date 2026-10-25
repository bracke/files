separate (Files_Suite.Rendering)
   --  The palette is theme-aware through Guikit.Draw.Color_For. This is a
   --  legitimate palette assertion (the role-to-color mapping), not a fragile
   --  whole-frame color assertion: the light theme must differ from dark for a
   --  representative role, and high contrast must use its own stronger dark
   --  palette rather than silently aliasing the ordinary dark theme.
   procedure Test_Theme_Palette_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Palette_Color;
      Dark_Canvas : constant Palette_Color := Color_For (Canvas_Color, Theme_Dark);
      Light_Canvas : constant Palette_Color := Color_For (Canvas_Color, Theme_Light);
      Dark_Text   : constant Palette_Color := Color_For (Text_Color, Theme_Dark);
      Light_Text  : constant Palette_Color := Color_For (Text_Color, Theme_Light);
      Contrast_Canvas : constant Palette_Color := Color_For (Canvas_Color, Theme_High_Contrast);
      Contrast_Text   : constant Palette_Color := Color_For (Text_Color, Theme_High_Contrast);
      Contrast_Border : constant Palette_Color := Color_For (Border_Color, Theme_High_Contrast);
      Dark_Border     : constant Palette_Color := Color_For (Border_Color, Theme_Dark);
   begin
      Assert
        (Light_Canvas /= Dark_Canvas,
         "the light theme uses a different canvas color than dark");
      Assert
        (Light_Text /= Dark_Text,
         "the light theme uses a different text color than dark");
      Assert
        (Light_Canvas.R > Dark_Canvas.R,
         "the light theme canvas is lighter than the dark canvas");
      Assert
        (Light_Text.R < Dark_Text.R,
         "the light theme text is darker than the dark text");
      Assert (Contrast_Canvas /= Dark_Canvas,
              "high contrast has a distinct canvas palette");
      Assert (Contrast_Text.R > Dark_Text.R,
              "high contrast text is brighter than dark-theme text");
      Assert (Contrast_Border.R > Dark_Border.R,
              "high contrast borders are stronger than dark-theme borders");
      Assert
        (Color_For (Canvas_Color) = Dark_Canvas,
         "the palette defaults to the dark theme");
   end Test_Theme_Palette_Selection;
