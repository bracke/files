separate (Files.Rendering)
   function Calculate_Info_Pane_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Info_Pane_Layout
   is
      function Total_Info_Rows return Natural is
         Rows   : Natural := 0;
         Text_W : constant Natural :=
           Info_Text_Width (Layout, Scrollbar_W => Natural'Min (Scrollbar_Width, Layout.Info_Pane_Width));
      begin
         --  A multi-item selection is drawn field-major (one label per section,
         --  a value row per item); a single selection keeps the per-item block.
         if Natural (Snapshot.Selected_Info.Length) >= 2 then
            return Coalesced_Info_Rows (Coalesced_Info_Sections (Snapshot), Text_W, Line_Height);
         end if;

         for Info of Snapshot.Selected_Info loop
            Rows :=
              Saturating_Add
                (Rows,
                 Info_Section_Row_Count (Info, Text_W, Line_Height));
         end loop;

         return Rows;
      end Total_Info_Rows;

      Pane_X        : constant Natural := Layout.Main_Width;
      Bar_W         : constant Natural := Natural'Min (Scrollbar_Width, Layout.Info_Pane_Width);
      Text_W        : constant Natural := Info_Text_Width (Layout, Bar_W);
      --  The combined selection total is now the last line of the Contents
      --  section (counted by Total_Info_Rows), so no header rows are reserved.
      Content_Rows  : constant Natural := Total_Info_Rows;
      Raw_Content_H : constant Natural := Saturating_Multiply (Content_Rows, Line_Height);
      Content_H     : constant Natural :=
        (if Raw_Content_H > 0
         then Saturating_Add (Raw_Content_H, Saturating_Multiply (Info_Pane_Padding, 2))
         else 0);
      Max_Scroll_Px : constant Natural :=
        (if Content_H > Layout.Main_Height then Content_H - Layout.Main_Height else 0);
      Requested_Px  : constant Natural := Saturating_Multiply (Snapshot.Info_Pane_Scroll_Lines, Line_Height);
      Scroll_Px     : constant Natural := Natural'Min (Requested_Px, Max_Scroll_Px);
      Scroll_Lines  : constant Natural := Scroll_Px / Line_Height;
      Thumb         : constant Guikit.Layout.Scrollbar_Thumb :=
        Guikit.Layout.Calculate_Scrollbar_Thumb
          (Track_Length    => Layout.Main_Height,
           Visible_Amount  => Layout.Main_Height,
           Total_Amount    => Content_H,
           Scroll_Position => Scroll_Px,
           Max_Scroll      => Max_Scroll_Px,
           Min_Length      => Line_Height);
      Visible       : constant Boolean :=
        Snapshot.Info_Pane_Open
        and then Layout.Info_Pane_Width > 0
        and then Bar_W > 0
        and then Thumb.Length > 0;
      Thumb_H       : constant Natural := Thumb.Length;
      Thumb_Y       : constant Natural := Saturating_Add (Layout.Main_Y, Thumb.Offset);
   begin
      if not Snapshot.Info_Pane_Open or else Layout.Info_Pane_Width = 0 then
         return (others => <>);
      end if;

      return
        (X                 => Pane_X,
         Y                 => Layout.Main_Y,
         Width             => Layout.Info_Pane_Width,
         Height            => Layout.Main_Height,
         Content_Height    => Content_H,
         Scroll_Lines      => Scroll_Lines,
         Scroll_Pixels     => Scroll_Px,
         Scrollbar_Visible => Visible,
         Scrollbar_X       => (if Visible then Saturating_Add (Pane_X, Layout.Info_Pane_Width - Bar_W) else 0),
         Scrollbar_Y       => (if Visible then Layout.Main_Y else 0),
         Scrollbar_Thumb_Y => (if Visible then Thumb_Y else 0),
         Scrollbar_Width   => (if Visible then Bar_W else 0),
         Scrollbar_Height  => (if Visible then Natural'Min (Thumb_H, Layout.Main_Height) else 0),
         Scrollbar_Track_Height => (if Visible then Layout.Main_Height else 0));
   end Calculate_Info_Pane_Layout;
