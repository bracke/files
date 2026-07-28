separate (Files.Rendering)
   function Calculate_Breadcrumb_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Line_Height : Positive := 20)
      return Breadcrumb_Segment_Layout_Vectors.Vector
   is
      Result       : Breadcrumb_Segment_Layout_Vectors.Vector;
      Toolbar      : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width);
      Field_Margin : constant Natural := 6;
      Path_X       : constant Natural := Saturating_Add (Toolbar.Middle_X, Field_Margin);
      Path_W       : constant Natural :=
        (if Toolbar.Middle_Width > Saturating_Multiply (Field_Margin, 2)
         then Toolbar.Middle_Width - Saturating_Multiply (Field_Margin, 2)
         else 0);
      Input_Y      : constant Natural := Guikit.Layout.Toolbar_Input_Y (Line_Height);
      Input_H      : constant Natural := Guikit.Layout.Toolbar_Input_Height (Line_Height);
      Pad          : constant Natural := Guikit.Layout.Input_Field_Padding;
      Star_Reserve : constant Natural := Path_Bar_Content_Offset (Width, Line_Height);
      Advance      : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Inner_X      : constant Natural := Saturating_Add (Saturating_Add (Path_X, Pad), Star_Reserve);
      Inner_W      : constant Natural :=
        (if Path_W > Saturating_Add (Saturating_Multiply (Pad, 2), Star_Reserve)
         then Path_W - Saturating_Add (Saturating_Multiply (Pad, 2), Star_Reserve)
         else 0);
      --  Separator occupies three cells: one blank cell, the '>' glyph, one
      --  blank cell -- a full character width of separation on each side.
      Sep_Cells    : constant Natural := 3;

      function Total_Cells
        (Src : Files.Breadcrumbs.Segment_Vectors.Vector)
         return Natural
      is
         Sum   : Natural := 0;
         Count : constant Natural := Natural (Src.Length);
      begin
         for I in 1 .. Count loop
            Sum := Saturating_Add (Sum, Files.UTF8.Display_Units (To_String (Src.Element (I).Label)));
            if I < Count then
               Sum := Saturating_Add (Sum, Sep_Cells);
            end if;
         end loop;
         return Sum;
      end Total_Cells;
   begin
      if Snapshot.Focus = Files.Types.Focus_Path_Input then
         return Result;
      elsif Snapshot.Breadcrumb_Segments.Is_Empty or else Inner_W = 0 then
         return Result;
      end if;

      declare
         Full           : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
           Snapshot.Breadcrumb_Segments;
         Count          : constant Natural := Natural (Full.Length);
         Capacity_Cells : constant Natural := Inner_W / Advance;
         Shown          : Files.Breadcrumbs.Segment_Vectors.Vector := Full;
         Cursor_X       : Natural := Inner_X;
      begin
         if Total_Cells (Full) > Capacity_Cells then
            declare
               Fitted : Boolean := False;
            begin
               for Max in reverse 3 .. Count loop
                  declare
                     Candidate : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
                       Files.Breadcrumbs.Elide (Full, Max);
                  begin
                     if Total_Cells (Candidate) <= Capacity_Cells then
                        Shown  := Candidate;
                        Fitted := True;
                        exit;
                     end if;
                  end;
               end loop;
               if not Fitted then
                  Shown := Files.Breadcrumbs.Elide (Full, Positive'Max (1, Natural'Min (3, Count)));
               end if;
            end;
         end if;

         for I in 1 .. Natural (Shown.Length) loop
            declare
               Seg        : constant Files.Breadcrumbs.Segment := Shown.Element (Positive (I));
               Cells      : constant Natural := Files.UTF8.Display_Units (To_String (Seg.Label));
               Seg_W      : constant Natural := Saturating_Multiply (Cells, Advance);
               Clickable  : constant Boolean := not Files.Breadcrumbs.Is_Ellipsis (Seg);
               Full_Index : Natural := 0;
            begin
               if Clickable then
                  for F in 1 .. Count loop
                     if Full.Element (Positive (F)).Ancestor_Path = Seg.Ancestor_Path then
                        Full_Index := F;
                        exit;
                     end if;
                  end loop;
               end if;
               Result.Append
                 (Breadcrumb_Segment_Layout'
                    (Segment_Index => Full_Index,
                     X             => Cursor_X,
                     Y             => Input_Y,
                     Width         => Seg_W,
                     Height        => Input_H,
                     Clickable     => Clickable and then Full_Index /= 0));
               Cursor_X :=
                 Saturating_Add
                   (Cursor_X,
                    Saturating_Add (Seg_W, Saturating_Multiply (Sep_Cells, Advance)));
            end;
         end loop;
      end;

      return Result;
   end Calculate_Breadcrumb_Layout;
