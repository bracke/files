separate (Files.Rendering)
   function Tree_Row_Capacity
     (Snapshot : View_Snapshot;
      Layout   : Tree_Panel_Layout)
      return Natural
   is
      Content_H : constant Natural := Tree_Content_Height (Snapshot, Layout);
   begin
      if Layout.Row_Height = 0 or else Content_H = 0 then
         return 0;
      end if;

      --  Count only fully visible rows, so the furthest scroll position
      --  shows the last folder whole rather than clipped by the panel edge
      --  or the pick-mode footer. A panel shorter than one row still shows
      --  that row, clipped.
      return Natural'Max (1, Content_H / Layout.Row_Height);
   end Tree_Row_Capacity;
