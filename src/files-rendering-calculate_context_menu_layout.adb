separate (Files.Rendering)
   function Calculate_Context_Menu_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Context_Menu_Layout
   is
      Result : Context_Menu_Layout;

      use type Files.Commands.Context_Menu_Row_Kind;
      use type Files.Model.Context_Menu_Target;
   begin
      if not Snapshot.Context_Menu_Open
        or else Snapshot.Context_Menu_Target = Files.Model.Context_Menu_None
      then
         return Result;
      end if;

      --  The row set (which commands, and where the separators fall) is shared
      --  with the controller's keyboard navigation via Files.Commands so both
      --  agree on the menu; here it is only laid out and hit-tested.
      declare
         Rows : constant Files.Commands.Context_Menu_Rows :=
           Files.Commands.Context_Menu_Rows_For (Snapshot.Context_Menu_Target);
      begin
         Result.Row_Count := Rows.Count;
         for Row in 1 .. Rows.Count loop
            Result.Commands (Row) := Rows.Rows (Row).Command;
            Result.Row_Kinds (Row) :=
              (if Rows.Rows (Row).Kind = Files.Commands.Menu_Command
               then Command_Row
               else Separator_Row);
         end loop;
      end;

      if Result.Row_Count = 0 then
         return Result;
      end if;

      Result.Padding := 4;
      Result.Row_Height :=
        Saturating_Add (Line_Height, Saturating_Multiply (Result.Padding, 2));
      --  A separator is just a 1px divider line surrounded by the row padding,
      --  so it takes noticeably less vertical space than a command row.
      Result.Separator_Height :=
        Saturating_Add (1, Saturating_Multiply (Result.Padding, 2));

      --  Size one column to the widest command label (using the same monospace
      --  cell metric and edge padding the renderer draws rows with).
      declare
         Cell_W    : constant Positive :=
           Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
         Edge_Pad  : constant Natural :=
           Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2);
         Max_Label : Natural := 0;
      begin
         for Row in 1 .. Result.Row_Count loop
            if Result.Row_Kinds (Row) = Command_Row then
               declare
                  Label : constant String :=
                    Files.Localization.Text
                      (Files.Commands.Name_Key (Result.Commands (Row)));
                  Label_W : constant Natural :=
                    Saturating_Multiply (Files.UTF8.Display_Units (Label), Cell_W);
               begin
                  Max_Label := Natural'Max (Max_Label, Label_W);
               end;
            end if;
         end loop;

         Result.Width :=
           Natural'Max
             (Natural'Max (Saturating_Multiply (Line_Height, 9), 180),
              Saturating_Add (Max_Label, Edge_Pad));
      end;

      declare
         Single_Column_Width : constant Natural := Result.Width;
         Outer_Padding       : constant Natural := Saturating_Multiply (Result.Padding, 2);
         Minimum_Column_W    : constant Natural :=
           Natural'Max (Saturating_Multiply (Line_Height, 9), 180);

         function Rows_Height (First_Row, Last_Row : Positive) return Natural is
            Value : Natural := 0;
         begin
            for Row in First_Row .. Last_Row loop
               Value :=
                 Saturating_Add
                   (Value,
                    (if Result.Row_Kinds (Row) = Separator_Row
                     then Result.Separator_Height
                     else Result.Row_Height));
            end loop;
            return Value;
         end Rows_Height;

         Total_Rows_Height : constant Natural := Rows_Height (1, Positive (Result.Row_Count));
         Best_Break        : Natural := 0;
         Best_Tallest      : Natural := Natural'Last;
      begin
         Result.Height := Saturating_Add (Total_Rows_Height, Outer_Padding);

         --  At compact heights, split only at a group separator.  This keeps
         --  every command mouse-reachable without shrinking text below its
         --  configured line height or cutting the menu off-screen.
         --  A narrow window still splits (columns then share its width and
         --  labels may be fitted): rows laid out below the window edge were
         --  unreachable by mouse, which is worse than shortened labels.
         if Result.Height > Height
           and then Result.Row_Count > 1
           and then Width >= Saturating_Multiply (Line_Height, 8)
         then
            for Row in 1 .. Result.Row_Count - 1 loop
               if Result.Row_Kinds (Row) = Separator_Row then
                  declare
                     Left_H  : constant Natural := Rows_Height (1, Row);
                     Right_H : constant Natural :=
                       Rows_Height (Positive (Row + 1), Positive (Result.Row_Count));
                     Tallest : constant Natural := Natural'Max (Left_H, Right_H);
                  begin
                     if Tallest < Best_Tallest then
                        Best_Tallest := Tallest;
                        Best_Break := Row;
                     end if;
                  end;
               end if;
            end loop;

            if Best_Break > 0
              and then Saturating_Add (Best_Tallest, Outer_Padding) <= Height
            then
               Result.Column_Count := 2;
               Result.Column_Break_Row := Best_Break;
               Result.Width :=
                 Natural'Min (Width, Saturating_Multiply (Single_Column_Width, 2));
               Result.Column_Width := Result.Width / 2;
               Result.Height := Saturating_Add (Best_Tallest, Outer_Padding);
            end if;
         end if;

         if Result.Column_Count = 1 then
            Result.Width := Natural'Min (Width, Single_Column_Width);
            Result.Column_Width := Result.Width;
         end if;
      end;

      --  Anchor to the cursor but keep the menu fully on-screen.
      Result.X :=
        (if Result.Width >= Width
         then 0
         elsif Snapshot.Context_Menu_X > Width - Result.Width
         then Width - Result.Width
         else Snapshot.Context_Menu_X);
      Result.Y :=
        (if Result.Height >= Height
         then 0
         elsif Snapshot.Context_Menu_Y > Height - Result.Height
         then Height - Result.Height
         else Snapshot.Context_Menu_Y);
      Result.Visible := Result.Width > 0 and then Result.Height > 0;

      return Result;
   end Calculate_Context_Menu_Layout;
