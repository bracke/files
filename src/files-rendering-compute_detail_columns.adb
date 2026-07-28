separate (Files.Rendering)
   function Compute_Detail_Columns
     (Visible     : Files.Types.Detail_Column_Visibility;
      Widths      : Files.Types.Detail_Column_Widths;
      Order       : Files.Types.Detail_Column_Order;
      Content_X   : Natural;
      Content_W   : Natural;
      Line_Height : Positive;
      Pad         : Natural)
      return Detail_Column_Geometry_Array
   is
      use type Files.Types.Detail_Column;
      Icon_Gap  : constant Natural := Saturating_Add (Line_Height, 6);
      Base_X    : constant Natural :=
        Saturating_Add (Saturating_Add (Content_X, Pad), Icon_Gap);
      Available : constant Natural :=
        (if Content_W > Saturating_Add (Icon_Gap, Saturating_Multiply (Pad, 2))
         then Content_W - Icon_Gap - Saturating_Multiply (Pad, 2)
         else 0);
      Min_Name  : constant Natural := Natural'Min (Available, Saturating_Multiply (Line_Height, 5));
      Result    : Detail_Column_Geometry_Array;
      Fixed_Sum : Natural := 0;
      Cursor    : Natural;
   begin
      --  Size each visible optional column in stored order, so the per-column
      --  width clamp (which reserves the name column's minimum) is applied in
      --  the same visual sequence the columns will be laid out.
      for Slot in Order'Range loop
         declare
            Column : constant Files.Types.Detail_Column := Order (Slot);
         begin
            if Column /= Files.Types.Name_Column and then Visible (Column) then
               declare
                  Raw   : constant Natural :=
                    (if Widths (Column) > 0
                     then Natural'Max (Widths (Column), Files.Types.Minimum_Detail_Column_Width)
                     else Default_Detail_Column_Width (Column, Line_Height));
                  Room  : constant Natural :=
                    (if Available > Saturating_Add (Fixed_Sum, Min_Name)
                     then Available - Fixed_Sum - Min_Name
                     else 0);
                  Width : constant Natural := Natural'Min (Raw, Room);
               begin
                  Result (Column) := (Visible => True, X => 0, Width => Width);
                  Fixed_Sum := Saturating_Add (Fixed_Sum, Width);
               end;
            end if;
         end;
      end loop;

      Result (Files.Types.Name_Column) :=
        (Visible => True,
         X       => Base_X,
         Width   => (if Available > Fixed_Sum then Available - Fixed_Sum else 0));

      --  Place columns left to right: the name column absorbs the remainder in
      --  the first slot, then the visible optional columns follow in stored
      --  order.
      Cursor := Saturating_Add (Base_X, Result (Files.Types.Name_Column).Width);
      for Slot in Order'Range loop
         declare
            Column : constant Files.Types.Detail_Column := Order (Slot);
         begin
            if Column /= Files.Types.Name_Column and then Result (Column).Visible then
               Result (Column).X := Cursor;
               Cursor := Saturating_Add (Cursor, Result (Column).Width);
            end if;
         end;
      end loop;

      return Result;
   end Compute_Detail_Columns;
