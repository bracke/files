separate (Files.Rendering)
   function Details_Header_Drop_Index
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      X           : Natural;
      Y           : Natural;
      Line_Height : Positive := 20)
      return Natural
   is
      use type Files.Types.Detail_Column;
      Content : constant Content_Rectangle := Main_Content_Rect (Layout);
      Content_X : constant Natural := Content.X;
      Content_Y : constant Natural := Content.Y;
      Content_W : constant Natural := Content.Width;
      Content_H : constant Natural := Content.Height;
      Header_H  : constant Natural :=
        Natural'Min
          (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
      Header_Pad : constant Natural := Natural'Min (Details_Row_Padding, Header_H);
      Columns   : constant Detail_Column_Geometry_Array :=
        Compute_Detail_Columns
          (Snapshot.Detail_Columns_Visible,
           Snapshot.Detail_Column_Widths,
           Snapshot.Detail_Column_Order,
           Content_X,
           Content_W,
           Line_Height,
           Header_Pad);
   begin
      if Snapshot.View_Mode /= Files.Types.Details
        or else Header_H = 0
        or else Y < Content_Y
        or else Y >= Saturating_Add (Content_Y, Header_H)
        or else X < Content_X
        or else X >= Saturating_Add (Content_X, Content_W)
      then
         return 0;
      end if;

      --  The dragged column takes the slot of the first visible optional column
      --  whose right edge is beyond the pointer (i.e. the one the pointer is
      --  over, or the first to its right). A pointer past all of them targets
      --  the final slot.
      for Slot in Snapshot.Detail_Column_Order'Range loop
         declare
            Column : constant Files.Types.Detail_Column :=
              Snapshot.Detail_Column_Order (Slot);
         begin
            if Column /= Files.Types.Name_Column
              and then Columns (Column).Visible
              and then X < Saturating_Add (Columns (Column).X, Columns (Column).Width)
            then
               return Slot;
            end if;
         end;
      end loop;

      return Files.Types.Detail_Column_Count;
   end Details_Header_Drop_Index;
