package body Files.Preference_Types is

   function Move_Column
     (Order    : Detail_Column_Order;
      Column   : Detail_Column;
      To_Index : Detail_Column_Index)
      return Detail_Column_Order
   is
      Target  : Detail_Column_Index := To_Index;
      From    : Detail_Column_Index := Detail_Column_Index'First;
      Found   : Boolean := False;
      Reduced : Detail_Column_Order;
      Count   : Natural := 0;
      Result  : Detail_Column_Order;
      Read    : Natural := 0;
   begin
      --  Name is pinned to the first slot and never moves; nor may any column
      --  displace it from the first slot.
      if Column = Name_Column then
         return Order;
      elsif Target < Detail_Column_Index'First + 1 then
         Target := Detail_Column_Index'First + 1;
      end if;

      --  Collect the order minus Column into Reduced, recording Column's slot.
      for Index in Order'Range loop
         if Order (Index) = Column then
            From := Index;
            Found := True;
         else
            Count := Count + 1;
            Reduced (Count) := Order (Index);
         end if;
      end loop;

      if not Found or else From = Target then
         return Order;
      end if;

      --  Re-emit the reduced sequence, inserting Column at the target slot.
      for Index in Result'Range loop
         if Index = Target then
            Result (Index) := Column;
         else
            Read := Read + 1;
            Result (Index) := Reduced (Read);
         end if;
      end loop;

      return Result;
   end Move_Column;

end Files.Preference_Types;
