separate (Files.Model)
   function Hidden_Item_Count
     (Model : Window_Model)
      return Natural
   is
      Count : Natural := 0;
   begin
      for Item of Model.Items loop
         declare
            Name : constant String := To_String (Item.Name);
         begin
            if Name'Length > 0 and then Name (Name'First) = '.' then
               Count := Count + 1;
            end if;
         end;
      end loop;

      return Count;
   end Hidden_Item_Count;
