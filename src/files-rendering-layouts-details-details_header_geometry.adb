separate (Files.Rendering.Layouts.Details)
   function Details_Header_Geometry
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Details_Header_Layout
   is
      Content  : constant Content_Rectangle := Main_Content_Rect (Layout);
      Header_H : constant Natural := Details_Header_Height (Content.Height, Line_Height);
      --  The header text's own inset, kept inside a header shorter than it.
      Pad      : constant Natural := Natural'Min (Details_Row_Padding (Line_Height), Header_H);
   begin
      return
        (Content => Content,
         Height  => Header_H,
         Pad     => Pad,
         --  The rows' padding, exactly as Calculate_Item_Layout passes it, so
         --  the header, its hit test, the dividers and the rows share one
         --  column geometry.
         Columns =>
           Compute_Detail_Columns
             (Snapshot.Detail_Columns_Visible,
              Snapshot.Detail_Column_Widths,
              Snapshot.Detail_Column_Order,
              Content.X,
              Content.Width,
              Line_Height,
              Details_Row_Padding (Line_Height)));
   end Details_Header_Geometry;
