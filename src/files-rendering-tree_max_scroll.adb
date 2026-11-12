separate (Files.Rendering)
   function Tree_Max_Scroll
     (Snapshot : View_Snapshot;
      Layout   : Tree_Panel_Layout)
      return Natural
   is
      Count    : constant Natural := Natural (Snapshot.Tree_Rows.Length);
      Capacity : constant Natural := Tree_Row_Capacity (Snapshot, Layout);
   begin
      return (if Count > Capacity then Count - Capacity else 0);
   end Tree_Max_Scroll;
