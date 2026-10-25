separate (Files_Suite.Rendering)
   procedure Test_Marquee_Auto_Scroll_Step (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  A rows region from y=100 to y=500, rows 20px tall (so a 20px edge zone).
      Top    : constant Integer := 100;
      Bottom : constant Integer := 500;
      LH     : constant Positive := 20;

      function Step (Cursor_Y : Integer) return Integer is
        (Marquee_Auto_Scroll_Step (Cursor_Y, Top, Bottom, LH));
   begin
      --  Comfortably inside the region: no scroll.
      Files_Suite.Support.Assert_Equal (Step (300), 0, "a pointer well inside the region does not scroll");
      Files_Suite.Support.Assert_Equal (Step (Top + LH), 0, "the pointer just past the top edge zone does not scroll");
      Files_Suite.Support.Assert_Equal
        (Step (Bottom - LH),
         0,
         "the pointer just past the bottom edge zone does not scroll");

      --  Within the edge zone or beyond: scroll toward that edge, accelerating.
      Files_Suite.Support.Assert_Equal (Step (Top + LH - 1), -1, "entering the top edge zone scrolls up by one line");
      Files_Suite.Support.Assert_Equal (Step (Top), -2, "at the top edge the upward step grows");
      Files_Suite.Support.Assert_Equal
        (Step (Bottom - LH + 1),
         1,
         "entering the bottom edge zone scrolls down by one line");
      Files_Suite.Support.Assert_Equal (Step (Bottom), 2, "at the bottom edge the downward step grows");

      --  Far past an edge (pointer dragged outside the window): capped at 4.
      Files_Suite.Support.Assert_Equal (Step (-1000), -4, "far above the region the upward step is capped");
      Files_Suite.Support.Assert_Equal (Step (5000), 4, "far below the region the downward step is capped");

      --  Directions are opposite and symmetric about the region.
      Assert (Step (50) < 0 and then Step (600) > 0, "above scrolls up, below scrolls down");

      --  Coordinate-limit input is still capped instead of overflowing.
      Files_Suite.Support.Assert_Equal
        (Marquee_Auto_Scroll_Step (Integer'First, Integer'Last, Integer'Last, Positive'Last),
         -4,
         "extreme top-edge arithmetic remains capped");
      Files_Suite.Support.Assert_Equal
        (Marquee_Auto_Scroll_Step (Integer'Last, Integer'First, Integer'First, Positive'Last),
         4,
         "extreme bottom-edge arithmetic remains capped");
   end Test_Marquee_Auto_Scroll_Step;
