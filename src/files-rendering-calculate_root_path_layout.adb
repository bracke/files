separate (Files.Rendering)
   function Calculate_Root_Path_Layout
     (Snapshot : View_Snapshot;
      Layout   : Root_Selector_Layout)
      return Root_Path_Layout_Vectors.Vector
   is
      Result       : Root_Path_Layout_Vectors.Vector;
      Root_Count   : constant Natural := Natural (Snapshot.Root_Paths.Length);
      Content_H    : constant Natural :=
        (if Layout.Height > Saturating_Multiply (Root_Selector_Padding, 2)
         then Layout.Height - Saturating_Multiply (Root_Selector_Padding, 2)
         else 0);
      Content_W    : constant Natural :=
        (if Layout.Width > Saturating_Multiply (Root_Selector_Padding, 2)
         then Layout.Width - Saturating_Multiply (Root_Selector_Padding, 2)
         else Layout.Width);
      Visible_Rows : constant Natural := Visible_Row_Count (Content_H, Layout.Row_Height);
      Start_Index  : Natural := 1;
      Selected_Index : Natural := Snapshot.Root_Selected_Index;
   begin
      if not Snapshot.Root_Selector_Open
        or else Layout.Row_Height = 0
        or else Root_Count = 0
      then
         return Result;
      end if;

      if Selected_Index > Root_Count then
         Selected_Index := Root_Count;
      end if;

      if Visible_Rows > 0 and then Selected_Index > Visible_Rows then
         Start_Index := Selected_Index - Visible_Rows + 1;
      end if;

      if Start_Index > Root_Count then
         Start_Index := Root_Count;
      end if;

      for Index in Start_Index .. Root_Count loop
         declare
            Row_Y : constant Natural :=
              Saturating_Add
                (Saturating_Add (Layout.Y, Root_Selector_Padding),
                 Saturating_Multiply (Natural (Index - Start_Index), Layout.Row_Height));
            Layout_End_Y : constant Natural :=
              Saturating_Add
                (Layout.Y,
                 (if Layout.Height > Root_Selector_Padding then Layout.Height - Root_Selector_Padding else 0));
         begin
            exit when Row_Y >= Layout_End_Y;
            declare
               Remaining : constant Natural := Layout_End_Y - Row_Y;
               Row_H     : constant Natural := Natural'Min (Layout.Row_Height, Remaining);
            begin
               Result.Append
                 (Root_Path_Layout'
                    (Root_Index => Index,
                     X          => Saturating_Add (Layout.X, Root_Selector_Padding),
                     Y          => Row_Y,
                     Width      => Content_W,
                     Height     => Row_H,
                     Selected   => Index = Selected_Index));
            end;
         end;
      end loop;

      return Result;
   end Calculate_Root_Path_Layout;
