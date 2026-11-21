separate (Files.Rendering.Layouts)
   function Calculate_Item_Layout
     (Snapshot      : View_Snapshot;
      Layout        : Layout_Metrics;
      Line_Height   : Positive;
      Whole_Content : Boolean := False;
      Window_Top    : Natural := 0;
      Window_Height : Natural := 0)
      return Item_Layout_Vectors.Vector
   is
      Placed : constant Placed_Item_Layout :=
        Place_Item_Layout (Snapshot, Layout, Line_Height, Whole_Content, Window_Top, Window_Height);
      Result : Item_Layout_Vectors.Vector;
   begin
      Result.Set_Length (Snapshot.Items.Length);
      for Offset in 0 .. Natural (Placed.Cells.Length) - 1 loop
         Result.Replace_Element (Placed.First + Offset, Placed.Cells (Offset + 1));
      end loop;
      return Result;
   end Calculate_Item_Layout;
