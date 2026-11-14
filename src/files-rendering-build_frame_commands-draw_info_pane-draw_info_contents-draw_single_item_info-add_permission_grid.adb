separate (Files.Rendering.Build_Frame_Commands.Draw_Info_Pane.Draw_Info_Contents.Draw_Single_Item_Info)
   --  Draw the permissions matrix: a "Permissions" label, an
   --  R/W/E column header, a 3x3 rwx grid (rows user/group/other,
   --  columns read/write/execute) with a per-row label, and -- when
   --  editable -- one click hit region per cell. Cell index Bit
   --  maps to POSIX mode bit 2 ** (8 - Bit); a filled cell is set.
   procedure Add_Permission_Grid is
      Cell_Inset : constant Natural := Guikit.Layout.Scaled (6, Line_Height);
      Cell : constant Natural :=
        Natural'Max (Cell_Inset, (if Line_Height > Cell_Inset then Line_Height - Cell_Inset else 0));
      Gap  : constant Natural := Natural'Max (Guikit.Layout.Scaled (2, Line_Height), Line_Height / 6);
      --  Approximate glyph advance, used to horizontally centre a
      --  header letter over its column.
      Char_W : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      --  The glyph box is ~4/5 of the line height and sits at the
      --  bottom of the row (the leading is above it), so centre the
      --  cell square within that font box -- not the whole line --
      --  to line it up with the row label text.
      Font_H : constant Natural := Saturating_Multiply (Line_Height, 4) / 5;
      Cell_Top : constant Natural :=
        (if 2 * Line_Height > Font_H + Cell then Line_Height - (Font_H + Cell) / 2 + 1 else 0);
      --  Horizontal inset that centres a header letter over a cell.
      Header_Pad : constant Natural := Centered (Cell, Char_W);
      --  The row labels sit just past the three columns.
      Labels_X : constant Natural :=
        Guikit.Layout.Saturating_Add
          (Text_X, Guikit.Layout.Saturating_Add (Saturating_Multiply (3, Cell + Gap), Gap));
      Labels_W : constant Natural :=
        (if Text_W > Labels_X - Text_X then Text_W - (Labels_X - Text_X) else 0);

      --  Draw a clipped label/glyph at a section-row offset.
      procedure Add_At (X : Natural; Section_Row : Natural; Width : Natural; Text : String) is
         Y : constant Integer :=
           Saturating_Integer_Add (Row_Y, Saturating_Multiply (Section_Row, Line_Height));
      begin
         if Width > 0
           and then Y >= Integer (Info_Pane.Y)
           and then Y < Integer (Info_Bottom)
         then
            Add_Text
              (X,
               Natural (Y),
               Width,
               Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
               To_Unbounded_String (Text), Muted_Text_Color, Fit => True);
         end if;
      end Add_At;

      Column_Header : constant array (0 .. 2) of Character := ('R', 'W', 'E');

      function Row_Label_Key (Row : Natural) return String is
        (case Row is
            when 0      => "info.permissions.user",
            when 1      => "info.permissions.group",
            when others => "info.permissions.other");
   begin
      Add_Info_Label (Current_Row, Info_Field_Label_Key (Info_Permissions));

      --  R/W/E header, one letter centred over each column.
      for Col in 0 .. 2 loop
         Add_At
           (Guikit.Layout.Saturating_Add
              (Guikit.Layout.Saturating_Add (Text_X, Saturating_Multiply (Col, Cell + Gap)), Header_Pad),
            Current_Row + 1, Char_W, [1 => Column_Header (Col)]);
      end loop;

      for Bit in 0 .. 8 loop
         declare
            Col   : constant Natural := Bit mod 3;
            Row   : constant Natural := Bit / 3;
            Cell_X : constant Natural :=
              Guikit.Layout.Saturating_Add (Text_X, Saturating_Multiply (Col, Cell + Gap));
            Cell_Y : constant Integer :=
              Saturating_Integer_Add
                (Saturating_Integer_Add
                   (Row_Y,
                    Saturating_Multiply (Guikit.Layout.Saturating_Add (Current_Row + 2, Row), Line_Height)),
                 Cell_Top);
            Is_Set : constant Boolean :=
              (Info.Mode_Bits / (2 ** (8 - Bit))) mod 2 = 1;
         begin
            if Cell_Y >= Integer (Info_Pane.Y)
              and then Cell_Y + Integer (Cell) <= Integer (Info_Bottom)
            then
               Add_Rect (Cell_X, Natural (Cell_Y), Cell, Cell, Border_Color);
               if Cell > 2 then
                  Add_Rect
                    (Guikit.Layout.Saturating_Add (Cell_X, 1),
                     Natural (Cell_Y) + 1,
                     Cell - 2,
                     Cell - 2,
                     (if Is_Set then Selection_Color else Input_Color));
               end if;
               if Snapshot.Permissions_Editable then
                  Result.Permission_Hits.Append
                    (Permission_Hit_Region'
                       (Present => True,
                        Bit     => Bit,
                        X       => Cell_X,
                        Y       => Natural (Cell_Y),
                        Width   => Cell,
                        Height  => Cell));
               end if;
            end if;
         end;
      end loop;

      --  Per-row labels: user / group / other.
      for Row in 0 .. 2 loop
         Add_At
           (Labels_X, Current_Row + 2 + Row, Labels_W,
            Files.Localization.Text (Row_Label_Key (Row)));
      end loop;

      Current_Row := Guikit.Layout.Saturating_Add (Current_Row, Permission_Grid_Rows);
   end Add_Permission_Grid;
