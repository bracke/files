separate (Files_Suite.Rendering)
   --  The counts/free geometry split used by both the renderer and the
   --  click hit-test.
   procedure Test_Split_Status_Region (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      TW, DX, FX, FW : Natural;
   begin
      --  No free field: the toggle spans the whole status region.
      Files.UI.Split_Status_Region (200, 300, 0, TW, DX, FX, FW);
      Files_Suite.Support.Assert_Equal (TW, 300, "with no free field the toggle spans the whole info region (TW)");
      Files_Suite.Support.Assert_Equal (DX, 0, "with no free field the toggle spans the whole info region (DX)");
      Files_Suite.Support.Assert_Equal (FX, 0, "with no free field the toggle spans the whole info region (FX)");
      Files_Suite.Support.Assert_Equal (FW, 0, "with no free field the toggle spans the whole info region (FW)");

      --  Too narrow for the free field plus divider gaps: no split.
      Files.UI.Split_Status_Region (200, 80, 60, TW, DX, FX, FW);
      Assert (TW = 80 and then FW = 0,
              "a too-narrow region keeps the toggle spanning the whole width");

      --  A long disk-space label must not squeeze a complete compact count into
      --  an ellipsis; in that case the secondary free-space field yields.
      Files.UI.Split_Status_Region (200, 256, 168, TW, DX, FX, FW);
      Assert (TW = 256 and then FW = 0,
              "free space yields before truncating the compact count summary");

      --  Room for the free field: carved off on the right, divider one gap left.
      Files.UI.Split_Status_Region (200, 300, 60, TW, DX, FX, FW);
      Files_Suite.Support.Assert_Equal (FX, 436, "the free field sits right-aligned within the region");
      Files_Suite.Support.Assert_Equal (DX, 428, "the divider sits one gap left of the free field");
      Files_Suite.Support.Assert_Equal (TW, 228, "the toggle covers only up to the divider");
      Files_Suite.Support.Assert_Equal (FW, 64, "the free field box is the label width plus padding");
      Assert (200 + TW = DX and then FX + FW = 200 + 300,
              "toggle, divider gap and free field partition the region");
   end Test_Split_Status_Region;
