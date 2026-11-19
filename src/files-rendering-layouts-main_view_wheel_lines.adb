separate (Files.Rendering.Layouts)
   function Main_View_Wheel_Lines
     (Main        : Main_View_Layout;
      Line_Height : Positive;
      Maximum     : Natural;
      Lines       : Integer)
      return Natural
   is
      Stride  : constant Long_Long_Integer := Long_Long_Integer (Positive'Max (1, Main.Row_Stride));
      LH      : constant Long_Long_Integer := Long_Long_Integer (Line_Height);
      Up      : constant Boolean := Lines < 0;
      Rows    : constant Long_Long_Integer := Long_Long_Integer'Max (1, abs Long_Long_Integer (Lines) * LH / Stride);
      Drawn   : constant Long_Long_Integer := Long_Long_Integer (Main.Scroll_Pixels);
      --  The row boundary at or above (going up) or below (going down) the
      --  drawn offset, which is off a boundary only at the very end.
      Floor   : constant Long_Long_Integer := Drawn / Stride * Stride;
      Ceiling : constant Long_Long_Integer := (if Floor = Drawn then Drawn else Floor + Stride);
      Target  : constant Long_Long_Integer :=
        (if Up then Long_Long_Integer'Max (0, Ceiling - Rows * Stride) else Floor + Rows * Stride);
      Bounded : constant Natural := Natural (Long_Long_Integer'Min (Target, Long_Long_Integer (Natural'Last)));
   begin
      return Natural'Min (Maximum, Lines_For_Offset (Main, Line_Height, Bounded, Up));
   end Main_View_Wheel_Lines;
