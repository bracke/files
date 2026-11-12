separate (Files.Rendering)
   function Row_Position_Of
     (Snapshot      : View_Snapshot;
      Visible_Index : Natural)
      return Natural
   is
   begin
      if Visible_Index = 0 then
         return 0;
      end if;
      --  Without group headers the row is the visible index itself.
      if Visible_Index <= Natural (Snapshot.Items.Length)
        and then Snapshot.Items (Snapshot.Items.First_Index + Visible_Index - 1).Visible_Index = Visible_Index
      then
         return Visible_Index;
      end if;
      for Index in Snapshot.Items.First_Index .. Snapshot.Items.Last_Index loop
         if Snapshot.Items (Index).Visible_Index = Visible_Index then
            return Index - Snapshot.Items.First_Index + 1;
         end if;
      end loop;
      return 0;
   end Row_Position_Of;
