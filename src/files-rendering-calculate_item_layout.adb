separate (Files.Rendering)
   function Calculate_Item_Layout
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive;
      Whole_Content : Boolean := False;
      Window_Top    : Natural := 0;
      Window_Height : Natural := 0)
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
           Details_Row_Padding (Line_Height));
      View : constant Guikit.Item_Grid.View_Kind := Grid_View (Snapshot.View_Mode);
      Columns : Guikit.Item_Grid.Detail_Column_Bounds;

      --  By name, so a reordered or extended enum on either side fails to
      --  compile instead of mislabelling columns.
      function As_Grid_Column (C : Files.Types.Detail_Column) return Guikit.Item_Grid.Detail_Column is
        (case C is
            when Files.Types.Name_Column        => Guikit.Item_Grid.Name_Column,
            when Files.Types.Modified_Column    => Guikit.Item_Grid.Modified_Column,
            when Files.Types.Size_Column        => Guikit.Item_Grid.Size_Column,
            when Files.Types.Filetype_Column    => Guikit.Item_Grid.Filetype_Column,
            when Files.Types.Created_Column     => Guikit.Item_Grid.Created_Column,
            when Files.Types.Permissions_Column => Guikit.Item_Grid.Permissions_Column);

      --  Read in place: only the cells on screen ask for their name.
      function Visible_Index_At (Position : Positive) return Natural is
        (Snapshot.Items.Constant_Reference (Position).Visible_Index);
      function Is_Header_At (Position : Positive) return Boolean is
        (Snapshot.Items.Constant_Reference (Position).Is_Group_Header);
      function Label_At (Position : Positive) return String is
        (To_String (Snapshot.Items.Constant_Reference (Position).Name));
   begin
      for C in Files.Types.Detail_Column loop
         Columns (As_Grid_Column (C)) := (X => Geometry (C).X, Width => Geometry (C).Width);
      end loop;

      if Whole_Content and then Window_Height > 0 then
         --  Only the band's cells, still at their unscrolled places: the
         --  grid lays out what is on screen, so it is scrolled to the band
         --  (less a cell, for one the band's top cuts) while its top moves
         --  down by as much, which leaves every placed cell where the
         --  unscrolled content has it. The header row and a cell's worth
         --  more below keep the band's last row whole.
         declare
            Cell   : constant Guikit.Item_Grid.Cell_Metrics :=
              Guikit.Item_Grid.Cell_Metrics_For (View, Content_W, Line_Height);
            Margin : constant Natural :=
              Guikit.Layout.Saturating_Add
                (Guikit.Layout.Saturating_Add (Cell.Height, Guikit.Item_Grid.Grid_Gap (Line_Height)), Line_Height * 2);
            Top    : constant Natural := (if Window_Top > Content_Y then Window_Top - Content_Y else 0);
            Shift  : constant Natural := (if Top > Margin then Top - Margin else 0);
         begin
            return Guikit.Item_Grid.Calculate_Layout
              (Count            => Natural (Snapshot.Items.Length),
               Visible_Index_At => Visible_Index_At'Access,
               Is_Header_At     => Is_Header_At'Access,
               Label_At         => Label_At'Access,
               View             => View,
               Content_X        => Content_X,
               Content_Y        => Guikit.Layout.Saturating_Add (Content_Y, Shift),
               Content_W        => Content_W,
               Content_H        =>
                 Guikit.Layout.Saturating_Add
                   (Guikit.Layout.Saturating_Add (Top - Shift, Window_Height),
                    Guikit.Layout.Saturating_Add (Margin, Margin)),
               Columns          => Columns,
               Scroll_Pixels    => Shift,
               Line_Height      => Line_Height);
         end;
      end if;

      return Guikit.Item_Grid.Calculate_Layout
        (Count            => Natural (Snapshot.Items.Length),
         Visible_Index_At => Visible_Index_At'Access,
         Is_Header_At     => Is_Header_At'Access,
         Label_At         => Label_At'Access,
         View             => View,
         Content_X        => Content_X,
         Content_Y        => Content_Y,
         Content_W        => Content_W,
         Content_H        =>
           --  The whole content below the header: the viewport plus all
           --  that scrolls, whatever the header takes.
           (if Whole_Content then Content_H + Main_View.Content_Height else Content_H),
         Columns          => Columns,
         Scroll_Pixels    => (if Whole_Content then 0 else Main_View.Scroll_Pixels),
         Line_Height      => Line_Height);
   end Calculate_Item_Layout;
