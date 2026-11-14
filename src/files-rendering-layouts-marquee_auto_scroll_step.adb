separate (Files.Rendering.Layouts)
   function Marquee_Auto_Scroll_Step
     (Cursor_Y      : Integer;
      Region_Top    : Integer;
      Region_Bottom : Integer;
      Line_Height   : Positive;
      Max_Step      : Positive := 4)
      return Integer
   is
      subtype Wide_Integer is Long_Long_Integer;

      Cursor      : constant Wide_Integer := Wide_Integer (Cursor_Y);
      Top_Edge    : constant Wide_Integer :=
        Wide_Integer (Region_Top) + Wide_Integer (Line_Height);
      Bottom_Edge : constant Wide_Integer :=
        Wide_Integer (Region_Bottom) - Wide_Integer (Line_Height);
      Line        : constant Wide_Integer := Wide_Integer (Line_Height);
      Limit       : constant Wide_Integer := Wide_Integer (Max_Step);
      Step        : Wide_Integer;
   begin
      if Cursor < Top_Edge then
         Step := Wide_Integer'Min
           (Limit, 1 + (Top_Edge - Cursor) / Line);
         return -Integer (Step);
      elsif Cursor > Bottom_Edge then
         Step := Wide_Integer'Min
           (Limit, 1 + (Cursor - Bottom_Edge) / Line);
         return Integer (Step);
      else
         return 0;
      end if;
   end Marquee_Auto_Scroll_Step;
