separate (Files.Rendering)
   function Calculate_Tree_Panel_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Tree_Panel_Layout
   is
      Preferred_Width : constant Natural :=
        Natural'Max (Layout.Width / 4, Saturating_Multiply (Line_Height, 16));
      Panel_Width     : constant Natural := Natural'Min (Layout.Width, Preferred_Width);
      Row_Height      : constant Natural :=
        Saturating_Add (Line_Height, Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2));
   begin
      if not Snapshot.Tree_Panel_Open then
         return (others => <>);
      end if;

      declare
         Base : constant Tree_Panel_Layout :=
           (X          => 0,
            Y          => Layout.Toolbar_Height,
            Width      => Panel_Width,
            Height     => Layout.Main_Height,
            Row_Height => Row_Height,
            others     => <>);
         Track_H  : constant Natural := Tree_Content_Height (Snapshot, Base);
         Capacity : constant Natural := Tree_Row_Capacity (Snapshot, Base);
         Count    : constant Natural := Natural (Snapshot.Tree_Rows.Length);
         Maximum  : constant Natural :=
           (if Count > Capacity then Count - Capacity else 0);
         Scroll   : constant Natural :=
           Natural'Min (Snapshot.Tree_Panel_Scroll_Rows, Maximum);
         Bar_W    : constant Natural := Natural'Min (Scrollbar_Width, Base.Width);
         Thumb    : constant Guikit.Layout.Scrollbar_Thumb :=
           Guikit.Layout.Calculate_Scrollbar_Thumb
             (Track_Length    => Track_H,
              Visible_Amount  => Capacity,
              Total_Amount    => Count,
              Scroll_Position => Scroll,
              Max_Scroll      => Maximum,
              Min_Length      => Line_Height);
         Visible  : constant Boolean :=
           Count > Capacity
           and then Capacity > 0
           and then Bar_W > 0
           and then Thumb.Length > 0;
         Track_Y  : constant Natural := Saturating_Add (Base.Y, Base.Row_Height);
      begin
         return
           (X          => Base.X,
            Y          => Base.Y,
            Width      => Base.Width,
            Height     => Base.Height,
            Row_Height => Base.Row_Height,
            Scrollbar_Visible => Visible,
            Scrollbar_X       =>
              (if Visible then Saturating_Add (Base.X, Base.Width - Bar_W) else 0),
            Scrollbar_Y       => (if Visible then Track_Y else 0),
            Scrollbar_Thumb_Y =>
              (if Visible then Saturating_Add (Track_Y, Thumb.Offset) else 0),
            Scrollbar_Width   => (if Visible then Bar_W else 0),
            Scrollbar_Height  => (if Visible then Thumb.Length else 0),
            Scrollbar_Track_Height => (if Visible then Track_H else 0));
      end;
   end Calculate_Tree_Panel_Layout;
