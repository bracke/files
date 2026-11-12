separate (Files.Rendering)
   function Main_View_Max_Scroll
     (Main        : Main_View_Layout;
      Line_Height : Positive)
      return Natural is
   begin
      if not Main.Scrollbar_Visible then
         return 0;
      end if;
      return Max_Scroll_Lines (Main.Content_Height, Main.Scrollbar_Track_Height, Line_Height);
   end Main_View_Max_Scroll;
