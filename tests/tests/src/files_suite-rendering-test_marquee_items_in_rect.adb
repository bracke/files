separate (Files_Suite.Rendering)
   procedure Test_Marquee_Items_In_Rect (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout   : constant Guikit.Draw.Layout_Metrics :=
        Calculate_Layout (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Items    : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);

      --  True when Hits contains exactly the ascending indices in Expected.
      function Exactly
        (Hits     : Visible_Index_Vectors.Vector;
         Expected : Visible_Index_Vectors.Vector)
         return Boolean is
      begin
         if Natural (Hits.Length) /= Natural (Expected.Length) then
            return False;
         end if;
         for Offset in 0 .. Natural (Expected.Length) - 1 loop
            if Hits.Element (Hits.First_Index + Offset)
              /= Expected.Element (Expected.First_Index + Offset)
            then
               return False;
            end if;
         end loop;
         return True;
      end Exactly;

      Cell_1 : constant Item_Layout := Items.Element (1);
      Cell_2 : constant Item_Layout := Items.Element (2);
      Rect_X : Natural;
      Rect_Y : Natural;
      Rect_W : Natural;
      Rect_H : Natural;
      Two    : Visible_Index_Vectors.Vector;
   begin
      Files_Suite.Support.Assert_Equal (Natural (Items.Length), 6, "the sample list lays out every item");

      Two.Append (1);
      Two.Append (2);

      --  A rectangle from inside cell 1 to inside cell 2 touches exactly those
      --  two cells (details rows stack vertically, so 1 and 2 are adjacent).
      declare
         Hits : constant Visible_Index_Vectors.Vector :=
           Files.Rendering.Hit.Items_In_Rect
             (Items,
              X      => Cell_1.X + Cell_1.Width / 2,
              Y      => Cell_1.Y + Cell_1.Height / 2,
              Width  => 1,
              Height => (Cell_2.Y + Cell_2.Height / 2) - (Cell_1.Y + Cell_1.Height / 2));
      begin
         Assert (Exactly (Hits, Two), "a rect spanning two cells returns exactly those two indices");
      end;

      --  Partial overlap counts as a hit: a one-pixel rectangle sitting on the
      --  top edge of cell 1 still touches it.
      declare
         Hits : constant Visible_Index_Vectors.Vector :=
           Files.Rendering.Hit.Items_In_Rect (Items, Cell_1.X + 1, Cell_1.Y, Width => 1, Height => 1);
      begin
         Assert (Natural (Hits.Length) = 1 and then Hits.First_Element = 1,
                 "a rectangle grazing a cell edge counts as a hit");
      end;

      --  Empty space well below every laid-out row touches nothing.
      declare
         Bottom : constant Natural := Layout.Main_Y + Layout.Main_Height;
         Hits   : constant Visible_Index_Vectors.Vector :=
           Files.Rendering.Hit.Items_In_Rect (Items, Layout.Main_X, Bottom + 100, Width => 20, Height => 20);
      begin
         Assert (Hits.Is_Empty, "a rect over empty space below the grid returns no items");
      end;

      --  A zero-area rectangle (a plain click, no drag) touches nothing.
      declare
         Hits : constant Visible_Index_Vectors.Vector :=
           Files.Rendering.Hit.Items_In_Rect (Items, Cell_1.X, Cell_1.Y, Width => 0, Height => 0);
      begin
         Assert (Hits.Is_Empty, "a zero-area marquee selects nothing (a plain click)");
      end;

      --  Normalization: details rows share an X, so a marquee spanning rows 1
      --  and 2 needs a nonzero width. Drag from a lower-right corner in row 2 up
      --  to an upper-left corner in row 1; the normalized rectangle (and hence
      --  its hits) must match the equivalent down-right drag over the same span.
      Marquee_Rect
        (Start_X   => Cell_2.X + 15,
         Start_Y   => Cell_2.Y + Cell_2.Height / 2,
         Current_X => Cell_1.X + 5,
         Current_Y => Cell_1.Y + Cell_1.Height / 2,
         X         => Rect_X,
         Y         => Rect_Y,
         Width     => Rect_W,
         Height    => Rect_H);
      Files_Suite.Support.Assert_Equal (Rect_X, Cell_1.X + 5, "up-left drag normalizes X to the min corner");
      Files_Suite.Support.Assert_Equal
        (Rect_Y,
         Cell_1.Y + Cell_1.Height / 2,
         "up-left drag normalizes Y to the min corner");
      Files_Suite.Support.Assert_Equal (Rect_W, 10, "the normalized width is the corner x distance");
      declare
         Hits : constant Visible_Index_Vectors.Vector :=
           Files.Rendering.Hit.Items_In_Rect (Items, Rect_X, Rect_Y, Rect_W, Rect_H);
      begin
         Assert (Exactly (Hits, Two), "an up-left drag selects the same two cells as down-right");
      end;
   end Test_Marquee_Items_In_Rect;
