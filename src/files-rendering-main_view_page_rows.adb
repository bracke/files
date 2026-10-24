separate (Files.Rendering)
   function Main_View_Page_Rows
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Positive
   is
      Main : constant Main_View_Layout := Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
   begin
      if Main.Row_Stride = 0 then
         return 1;
      end if;
      return Positive'Max (1, Main.Viewport_Height / Main.Row_Stride);
   end Main_View_Page_Rows;
