separate (Files.Rendering.Build_Frame_Commands.Draw_Main_View)
   --  The Details view's column dividers, down the rows on screen.
   procedure Draw_Column_Separators is
      Content   : constant Content_Rectangle := Main_Content_Rect (Layout);
      Content_X : constant Natural := Content.X;
      Content_W : constant Natural := Content.Width;
      Content_Y : constant Natural := Content.Y;
      Separator_Y : constant Natural := Content_Y;
      --  Bottom edge of the content viewport (excludes the bottom bar).
      Content_Bottom : constant Natural := Guikit.Layout.Saturating_Add (Content_Y, Content.Height);

      --  The dividers span the visible rows only: down to the bottom edge of
      --  the last row that is actually on screen, clamped to the viewport.
      --  They must not descend past the last visible line into empty space
      --  below the list (nor through the bottom bar).
      function Last_Visible_Bottom return Natural is
         Result : Natural := Content_Y;
      begin
         for Row of Items loop
            declare
               Row_Bottom : constant Natural := Guikit.Layout.Saturating_Add (Row.Y, Row.Height);
            begin
               if Row.Y < Content_Bottom and then Row_Bottom > Content_Y then
                  Result := Natural'Max (Result, Natural'Min (Row_Bottom, Content_Bottom));
               end if;
            end;
         end loop;
         return Result;
      end Last_Visible_Bottom;

      Separator_H : constant Natural := Last_Visible_Bottom - Separator_Y;
      Columns   : constant Detail_Column_Geometry_Array :=
        Compute_Detail_Columns
          (Snapshot.Detail_Columns_Visible,
           Snapshot.Detail_Column_Widths,
           Snapshot.Detail_Column_Order,
           Content_X,
           Content_W,
           Line_Height,
           Natural'Min (Details_Row_Padding (Line_Height), Line_Height));

      procedure Add_Column_Separator (Column_X : Natural) is
      begin
         Add_Rect
           ((if Column_X > Guikit.Layout.Scaled (2, Line_Height)
             then Column_X - Guikit.Layout.Scaled (2, Line_Height)
             else 0),
            Separator_Y, 1, Separator_H, Border_Color);
      end Add_Column_Separator;
   begin
      for Column in Files.Types.Optional_Detail_Column loop
         if Columns (Column).Visible then
            Add_Column_Separator (Columns (Column).X);
         end if;
      end loop;
   end Draw_Column_Separators;
