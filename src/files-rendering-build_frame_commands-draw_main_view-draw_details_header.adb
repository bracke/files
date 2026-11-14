separate (Files.Rendering.Build_Frame_Commands.Draw_Main_View)
   --  The Details view's column header row: its labels, sort marks, dividers
   --  and accessibility nodes.
   procedure Draw_Details_Header is
      Header    : constant Details_Header_Layout :=
        Details_Header_Geometry (Snapshot, Layout, Line_Height);
      Content_X : constant Natural := Header.Content.X;
      Header_H  : constant Natural := Header.Height;
      Header_Y  : constant Natural := Header.Content.Y;
      Header_W  : constant Natural := Header.Content.Width;
      --  Optically centre the label in the header field: lift it above the
      --  geometric inset, matching the bottom bar's text baseline
      --  (Bottom_Content_Y), so the glyphs read as centred rather than low.
      Text_Y    : constant Natural :=
        Guikit.Layout.Saturating_Add (Header_Y, Optically_Raised (Header.Pad, Line_Height));
      Columns   : Detail_Column_Geometry_Array renames Header.Columns;

      function Cell_X (Column_X : Natural) return Natural is
      begin
         return Guikit.Layout.Saturating_Add (Column_X, Details_Column_Padding (Line_Height));
      end Cell_X;

      function Cell_W (Column_W : Natural) return Natural is
      begin
         return
           (if Column_W > Details_Column_Padding (Line_Height)
            then Column_W - Details_Column_Padding (Line_Height) else 0);
      end Cell_W;

      function Header_Label (Column : Files.Types.Detail_Column) return String is
      begin
         case Column is
            when Files.Types.Name_Column =>
               return "details.name";
            when Files.Types.Modified_Column =>
               return "details.modified";
            when Files.Types.Size_Column =>
               return "details.size";
            when Files.Types.Filetype_Column =>
               return "details.filetype";
            when Files.Types.Created_Column =>
               return "details.created";
            when Files.Types.Permissions_Column =>
               return "details.permissions";
         end case;
      end Header_Label;

      function Header_Text (Column : Files.Types.Detail_Column) return UString is
         Label : constant String := Files.Localization.Text (Header_Label (Column));
         Sort  : constant Detail_Column_Sort := Detail_Column_Sorts (Column);
      begin
         if Sort.Sortable and then Snapshot.Sort_Field = Sort.Field then
            return To_Unbounded_String (Label & " " & Direction_Text);
         else
            return To_Unbounded_String (Label);
         end if;
      end Header_Text;

      function Header_Description return UString is
         Result : Unbounded_String := Null_Unbounded_String;
      begin
         for Column in Files.Types.Detail_Column loop
            if Columns (Column).Visible then
               if Length (Result) > 0 then
                  Append (Result, ", ");
               end if;
               Append (Result, Files.Localization.Text (Header_Label (Column)));
            end if;
         end loop;
         return Result;
      end Header_Description;
   begin
      Add_Rect (Content_X, Header_Y, Header_W, Header_H, Pane_Color);
      Add_Border (Content_X, Header_Y, Header_W, Header_H, Border_Color);
      for Column in Files.Types.Detail_Column loop
         if Columns (Column).Visible then
            Add_Text
              (Cell_X (Columns (Column).X),
               Text_Y,
               Cell_W (Columns (Column).Width),
               Line_Height,
               Header_Text (Column),
               Muted_Text_Color,
               Fit => True);
         end if;
      end loop;
      Add_Accessibility_Node
        (Role_Table_Row,
         Content_X,
         Header_Y,
         Header_W,
         Header_H,
         To_Unbounded_String (Files.Localization.Text ("details.header")),
         Header_Description);
      --  Each sortable cell on its own, so a screen reader can reach a
      --  column and activate it to sort, as a click on it does.
      for Column in Files.Types.Detail_Column loop
         if Columns (Column).Visible and then Detail_Column_Sorts (Column).Sortable then
            Add_Accessibility_Node
              (Role_Button,
               Columns (Column).X,
               Header_Y,
               Columns (Column).Width,
               Header_H,
               Header_Text (Column));
         end if;
      end loop;

      if Header_H > 0 then
         declare
            --  The separator sits this far left of its column, in the
            --  (scaled) column padding; the accent rule is this tall.
            Offset : constant Natural := Guikit.Layout.Scaled (2, Line_Height);
            Rule_H : constant Natural := Natural'Min (Guikit.Layout.Scaled (2, Line_Height), Header_H);
         begin
            for Column in Files.Types.Optional_Detail_Column loop
               if Columns (Column).Visible then
                  Add_Rect
                    ((if Columns (Column).X > Offset then Columns (Column).X - Offset else 0),
                     Header_Y, 1, Header_H, Border_Color);
               end if;
            end loop;
            Add_Rect
              (Content_X,
               Guikit.Layout.Saturating_Add (Header_Y, Header_H - Rule_H),
               Header_W,
               Rule_H,
               Selection_Color);
         end;
      end if;
   end Draw_Details_Header;
