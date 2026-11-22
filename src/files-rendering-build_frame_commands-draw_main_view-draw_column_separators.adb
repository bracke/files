with Files.Rendering.Layouts.Details;
with Files.Preference_Types;
separate (Files.Rendering.Build_Frame_Commands.Draw_Main_View)
   --  The Details view's column dividers, down the rows on screen.
   procedure Draw_Column_Separators is
      use Files.Rendering.Layouts.Details;
      Content   : constant Content_Rectangle := Main_Content_Rect (Layout);
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
         for Row of Items.Cells loop
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
      --  The header's columns: one geometry for header, dividers and rows.
      Columns   : constant Detail_Column_Geometry_Array :=
        Details_Header_Geometry (Snapshot, Layout, Line_Height).Columns;

      procedure Add_Column_Separator (Column_X : Natural) is
      begin
         Add_Rect (Column_Separator_X (Column_X, Line_Height), Separator_Y, 1, Separator_H, Border_Color);
      end Add_Column_Separator;
   begin
      for Column in Files.Preference_Types.Optional_Detail_Column loop
         if Columns (Column).Visible then
            Add_Column_Separator (Columns (Column).X);
         end if;
      end loop;
   end Draw_Column_Separators;
