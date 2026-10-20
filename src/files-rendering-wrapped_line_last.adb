separate (Files.Rendering)
   function Wrapped_Line_Last
     (Raw          : String;
      Start        : Integer;
      Segment_Last : Integer;
      Capacity     : Natural)
      return Integer
   is
      Prefix : constant String :=
        Files.UTF8.Prefix_By_Units (Raw (Start .. Segment_Last), Capacity);
      Limit  : constant Integer :=
        (if Prefix'Length = 0
         then Start
           + Integer (Files.UTF8.Next_Boundary (Raw (Start .. Segment_Last), 0)) - 1
         else Start + Prefix'Length - 1);
   begin
      if Limit >= Segment_Last then
         return Segment_Last;
      end if;

      for Position in reverse Start + 1 .. Limit loop
         if Raw (Position) = ' ' or else Raw (Position) = ASCII.HT then
            return Position - 1;
         end if;
      end loop;

      return Limit;
   end Wrapped_Line_Last;
