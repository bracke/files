separate (Files_Suite.Rendering)
   procedure Test_Extension_Label_Extreme_Height
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Label : constant Files.Extension_Labels.Label :=
        Files.Extension_Labels.Label_For ("txt", Natural'Last, Theme_Dark);
   begin
      Files_Suite.Support.Assert_Equal (Label.Width, 0, "an impossible extension-label size fails closed (width)");
      Files_Suite.Support.Assert_Equal (Label.Height, 0, "an impossible extension-label size fails closed (height)");
      Assert (Label.Pixels.Is_Empty, "an impossible extension-label size fails closed (pixels)");
   end Test_Extension_Label_Extreme_Height;
