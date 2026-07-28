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
      Content_X   : constant Natural := Saturating_Add (Layout.X, Padding);
      Panel_End_Y : constant Natural := Saturating_Add (Layout.Y, Layout.Height);
      Current     : constant String := To_String (Snapshot.Current_Path);
   begin
      if not Snapshot.Tree_Panel_Open or else Layout.Row_Height = 0 then
         return Result;
      end if;

      for I in 1 .. Natural (Snapshot.Tree_Rows.Length) loop
         declare
            TR    : constant Files.Folder_Tree.Visible_Row :=
              Snapshot.Tree_Rows.Element (Positive (I));
            Row_Y : constant Natural :=
              Saturating_Add
                (Saturating_Add (Layout.Y, Header_H),
                 Saturating_Multiply (Natural (I - 1), Layout.Row_Height));
         begin
            exit when Row_Y >= Panel_End_Y;
            declare
               Remaining    : constant Natural := Panel_End_Y - Row_Y;
               Row_H        : constant Natural := Natural'Min (Layout.Row_Height, Remaining);
               Depth_Indent : constant Natural := Saturating_Multiply (TR.Depth, Indent_W);
               Tri_X        : constant Natural := Saturating_Add (Content_X, Depth_Indent);
               Tri_Size     : constant Natural := Natural'Min (Line_Height, Row_H);
               Tri_Y        : constant Natural :=
                 (if Row_H > Tri_Size
                  then Saturating_Add (Row_Y, (Row_H - Tri_Size) / 2)
                  else Row_Y);
            begin
               Result.Append
                 (Tree_Row_Layout'
                    (Node_Index   => TR.Node_Index,
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
                     Triangle_W   => (if TR.Has_Children then Tri_Size else 0),
                     Triangle_H   => (if TR.Has_Children then Tri_Size else 0)));
            end;
         end;
      end loop;

      return Result;
   end Calculate_Tree_Row_Layout;
