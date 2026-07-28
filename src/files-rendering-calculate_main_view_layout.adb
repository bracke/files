separate (Files.Rendering)
   function Calculate_Main_View_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Main_View_Layout
   is
      Padding      : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Main_Content_Padding, 2)
           and then Layout.Main_Height > Saturating_Multiply (Main_Content_Padding, 2)
         then Main_Content_Padding
         else 0);
      Content_W    : constant Natural :=
        (if Layout.Main_Width > Saturating_Multiply (Padding, 2)
         then Layout.Main_Width - Saturating_Multiply (Padding, 2)
         else Layout.Main_Width);
      View_H       : constant Natural :=
        (if Layout.Main_Height > Saturating_Multiply (Padding, 2)
         then Layout.Main_Height - Saturating_Multiply (Padding, 2)
         else Layout.Main_Height);
      Count        : constant Natural := Natural (Snapshot.Items.Length);
      Metrics      : constant Item_Cell_Metrics :=
        Metrics_For (Snapshot.View_Mode, Content_W, Line_Height);
      Cell_W       : constant Natural := Metrics.Width;
      Cell_H       : constant Natural := Metrics.Height;
      Columns      : constant Natural :=
        (if Snapshot.View_Mode = Files.Types.Details or else Cell_W = 0
         then 1
         elsif Content_W < Cell_W
         then 1
         else Natural'Max
           (1,
            Saturating_Add (Content_W, Main_Grid_Gap) / Saturating_Add (Cell_W, Main_Grid_Gap)));
      Rows         : constant Natural := (if Count = 0 then 0 else 1 + (Count - 1) / Columns);
      Row_Content_H : constant Natural :=
        (if Rows = 0 then 0
         elsif Snapshot.View_Mode = Files.Types.Details
         then Saturating_Multiply (Rows, Cell_H)
         else Saturating_Add
           (Saturating_Multiply (Rows, Cell_H),
            Saturating_Multiply (Rows - 1, Main_Grid_Gap)));
      --  Details shows a sticky column header; its rows scroll in the area
      --  BELOW it. The scrollbar's viewport and track are therefore the rows
      --  area (View_H minus the header), starting below the header -- otherwise
      --  the track spans the non-scrolling header band and the ends misalign.
      Header_H      : constant Natural :=
        (if Snapshot.View_Mode = Files.Types.Details
         then Natural'Min
           (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), View_H)
         else 0);
      Viewport_H    : constant Natural := (if View_H > Header_H then View_H - Header_H else 0);
      Content_Total_H : constant Natural := Row_Content_H;
      Max_Scroll   : constant Natural :=
        (if Content_Total_H > Viewport_H then Content_Total_H - Viewport_H else 0);
      Requested_Px : constant Natural := Saturating_Multiply (Snapshot.Main_View_Scroll_Lines, Line_Height);
      Bounded_Px   : constant Natural := Natural'Min (Requested_Px, Max_Scroll);
      --  Snap the scroll offset to whole row periods so partially-scrolled
      --  rows at the top don't leave a visible empty band. Icons modes lay
      --  out rows on Cell_H + Main_Grid_Gap centers; Details has no row gap
      --  so the period is just Cell_H.
      Row_Stride   : constant Natural :=
        (if Snapshot.View_Mode = Files.Types.Details
         then Cell_H
         else Saturating_Add (Cell_H, Main_Grid_Gap));
      --  At the very end of the list use the exact Max_Scroll instead of the
      --  floored multiple: Max_Scroll is rarely a whole row period, and the
      --  per-item visibility test drops a row that doesn't fully fit, so
      --  flooring here would leave the final row permanently clipped/unreachable.
      Scroll_Px    : constant Natural :=
        (if Row_Stride > 0 and then Bounded_Px < Max_Scroll
         then (Bounded_Px / Row_Stride) * Row_Stride
         else Bounded_Px);
      Scroll_Lines : constant Natural := Scroll_Px / Line_Height;
      Bar_W        : constant Natural := Natural'Min (Scrollbar_Width, Layout.Main_Width);
      Thumb        : constant Guikit.Layout.Scrollbar_Thumb :=
        Guikit.Layout.Calculate_Scrollbar_Thumb
          (Track_Length    => Viewport_H,
           Visible_Amount  => Viewport_H,
           Total_Amount    => Content_Total_H,
           Scroll_Position => Scroll_Px,
           Max_Scroll      => Max_Scroll,
           Min_Length      => Line_Height);
      Visible      : constant Boolean := Bar_W > 0 and then Thumb.Length > 0;
      Thumb_H      : constant Natural := Thumb.Length;
      Track_Top    : constant Natural :=
        Saturating_Add (Saturating_Add (Layout.Main_Y, Padding), Header_H);
      Thumb_Y      : constant Natural := Saturating_Add (Track_Top, Thumb.Offset);
   begin
      return
        (Columns           => Positive'Max (1, Positive (Columns)),
         Content_Height    => Content_Total_H,
         Scroll_Lines      => Scroll_Lines,
         Scroll_Pixels     => Scroll_Px,
         Scrollbar_Visible => Visible,
         Scrollbar_X       => (if Visible then Saturating_Add (Layout.Main_X, Layout.Main_Width - Bar_W) else 0),
         Scrollbar_Y       => (if Visible then Track_Top else 0),
         Scrollbar_Thumb_Y => (if Visible then Thumb_Y else 0),
         Scrollbar_Width   => (if Visible then Bar_W else 0),
         Scrollbar_Height  => Thumb_H,
         Scrollbar_Track_Height => (if Visible then Viewport_H else 0));
   end Calculate_Main_View_Layout;
