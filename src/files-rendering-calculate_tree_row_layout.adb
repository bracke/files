separate (Files.Rendering)
   function Calculate_Tree_Row_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Tree_Panel_Layout;
      Line_Height : Positive := 20)
      return Tree_Row_Layout_Vectors.Vector
   is
      Result      : Tree_Row_Layout_Vectors.Vector;
      Padding     : constant Natural := Root_Selector_Padding;
      Indent_W    : constant Natural := Line_Height;
      Header_H    : constant Natural := Layout.Row_Height;
      Footer_H    : constant Natural :=
        (if Snapshot.Tree_Pick_Active
           and then Layout.Width > 0
           and then Layout.Row_Height > 0
           and then Layout.Height > Saturating_Multiply (Layout.Row_Height, 2)
         then Layout.Row_Height
         else 0);
      Content_X   : constant Natural := Saturating_Add (Layout.X, Padding);
      Panel_End_X : constant Natural := Saturating_Add (Layout.X, Layout.Width);
      Panel_End_Y : constant Natural :=
        Saturating_Add (Layout.Y, Layout.Height - Natural'Min (Layout.Height, Footer_H));
      Current     : constant String := To_String (Snapshot.Current_Path);
      Count       : constant Natural := Natural (Snapshot.Tree_Rows.Length);
      Capacity    : constant Natural := Tree_Row_Capacity (Snapshot, Layout);
      Max_First   : constant Natural :=
        (if Count > Capacity then Count - Capacity else 0);
      First_Row   : constant Natural :=
        Natural'Min (Snapshot.Tree_Panel_Scroll_Rows, Max_First);
   begin
      if not Snapshot.Tree_Panel_Open
        or else Layout.Row_Height = 0
        or else Capacity = 0
        or else Count = 0
      then
         return Result;
      end if;

      for I in First_Row + 1 .. Count loop
         declare
            TR    : constant Files.Folder_Tree.Visible_Row :=
              Snapshot.Tree_Rows.Element (Positive (I));
            Row_Y : constant Natural :=
              Saturating_Add
                (Saturating_Add (Layout.Y, Header_H),
                 Saturating_Multiply
                   (Natural (I - First_Row - 1), Layout.Row_Height));
         begin
            exit when Row_Y >= Panel_End_Y;
            declare
               Remaining    : constant Natural := Panel_End_Y - Row_Y;
               Row_H        : constant Natural := Natural'Min (Layout.Row_Height, Remaining);
               Depth_Indent : constant Natural := Saturating_Multiply (TR.Depth, Indent_W);
               Tri_X        : constant Natural := Saturating_Add (Content_X, Depth_Indent);
               Tri_Size     : constant Natural := Natural'Min (Line_Height, Row_H);
               Tri_W        : constant Natural :=
                 (if TR.Has_Children and then Tri_X < Panel_End_X
                  then Natural'Min (Tri_Size, Panel_End_X - Tri_X)
                  else 0);
               Tri_Y        : constant Natural :=
                 (if Row_H > Tri_Size
                  then Saturating_Add (Row_Y, (Row_H - Tri_Size) / 2)
                  else Row_Y);
            begin
               Result.Append
                 (Tree_Row_Layout'
                    (Visible_Row_Index => I,
                     Node_Index   => TR.Node_Index,
                     X            => Layout.X,
                     Y            => Row_Y,
                     Width        => Layout.Width,
                     Height       => Row_H,
                     Depth        => TR.Depth,
                     Expanded     => TR.Expanded,
                     Has_Children => TR.Has_Children,
                     Selected     =>
                       (if Snapshot.Tree_Pick_Active
                        then To_String (TR.Path) = To_String (Snapshot.Tree_Pick_Target)
                        else To_String (TR.Path) = Current),
                     Triangle_X   => Tri_X,
                     Triangle_Y   => Tri_Y,
                     Triangle_W   => Tri_W,
                     Triangle_H   => (if Tri_W > 0 then Tri_Size else 0)));
            end;
         end;
      end loop;

      return Result;
   end Calculate_Tree_Row_Layout;
