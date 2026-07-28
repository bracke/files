separate (Files.Rendering)
   function Calculate_Item_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Item_Layout_Vectors.Vector
   is
      Content : constant Content_Rectangle := Main_Content_Rect (Layout);
      Content_X : constant Natural := Content.X;
      Content_Y : constant Natural := Content.Y;
      Content_W : constant Natural := Content.Width;
      Content_H : constant Natural := Content.Height;
      Main_View : constant Main_View_Layout :=
        Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);

      --  Snapshot-derived inputs the component cannot compute itself: the detail
      --  column geometry (with the drawn-row padding) and the neutral item list.
      Geometry : constant Detail_Column_Geometry_Array :=
        Compute_Detail_Columns
          (Snapshot.Detail_Columns_Visible,
           Snapshot.Detail_Column_Widths,
           Snapshot.Detail_Column_Order,
           Content_X,
           Content_W,
           Line_Height,
           Details_Row_Padding);
      View : constant Guikit.Item_Grid.View_Kind := Grid_View (Snapshot.View_Mode);
      Columns : Guikit.Item_Grid.Detail_Column_Bounds;
      Items   : Guikit.Item_Grid.Layout_Item_Vectors.Vector;

      --  The two enums are identical (same six columns, same order).
      function As_Grid_Column (C : Files.Types.Detail_Column) return Guikit.Item_Grid.Detail_Column is
        (Guikit.Item_Grid.Detail_Column'Val (Files.Types.Detail_Column'Pos (C)));
   begin
      for C in Files.Types.Detail_Column loop
         Columns (As_Grid_Column (C)) := (X => Geometry (C).X, Width => Geometry (C).Width);
      end loop;

      for Index in 1 .. Natural (Snapshot.Items.Length) loop
         declare
            It : Item_Snapshot renames Snapshot.Items.Element (Positive (Index));
         begin
            Items.Append
              (Guikit.Item_Grid.Layout_Item'
                 (Visible_Index => It.Visible_Index,
                  Group_Header  => It.Is_Group_Header,
                  Label         => It.Name));
         end;
      end loop;

      return Guikit.Item_Grid.Calculate_Layout
        (Items         => Items,
         View          => View,
         Content_X     => Content_X,
         Content_Y     => Content_Y,
         Content_W     => Content_W,
         Content_H     => Content_H,
         Columns       => Columns,
         Scroll_Pixels => Main_View.Scroll_Pixels,
         Line_Height   => Line_Height);
   end Calculate_Item_Layout;
