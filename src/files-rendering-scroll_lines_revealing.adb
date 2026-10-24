separate (Files.Rendering)
   function Scroll_Lines_Revealing
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive;
      Visible_Index : Positive)
      return Natural
   is
      Main     : constant Main_View_Layout := Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
      Position : Natural := 0;
   begin
      for Index in Snapshot.Items.First_Index .. Snapshot.Items.Last_Index loop
         if Snapshot.Items (Index).Visible_Index = Visible_Index then
            Position := Index - Snapshot.Items.First_Index + 1;
            exit;
         end if;
      end loop;
      if Position = 0 or else Main.Row_Stride = 0 then
         return Snapshot.Main_View_Scroll_Lines;
      end if;
      declare
         Top    : constant Natural := Saturating_Multiply ((Position - 1) / Main.Columns, Main.Row_Stride);
         Bottom : constant Natural := Saturating_Add (Top, Main.Cell_Height);
         --  Wanted pixel offset; the layout snaps it down to a whole row, so
         --  a row that must end the view starts the next row period instead.
         Wanted : constant Natural :=
           (if Top < Main.Scroll_Pixels then Top
            elsif Bottom > Saturating_Add (Main.Scroll_Pixels, Main.Viewport_Height)
            then Natural'Min
              (Main.Max_Scroll_Pixels,
               Saturating_Multiply
                 ((Bottom - Main.Viewport_Height + Main.Row_Stride - 1) / Main.Row_Stride, Main.Row_Stride))
            else Main.Scroll_Pixels);
      begin
         if Wanted = Main.Scroll_Pixels then
            return Snapshot.Main_View_Scroll_Lines;
         end if;
         return (Wanted + Line_Height - 1) / Line_Height;
      end;
   end Scroll_Lines_Revealing;
