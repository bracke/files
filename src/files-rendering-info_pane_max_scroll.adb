separate (Files.Rendering)
   function Info_Pane_Max_Scroll
     (Info        : Info_Pane_Layout;
      Line_Height : Positive)
      return Natural is
   begin
      if not Info.Scrollbar_Visible then
         return 0;
      end if;
      return Max_Scroll_Lines (Info.Content_Height, Info.Height, Line_Height);
   end Info_Pane_Max_Scroll;
