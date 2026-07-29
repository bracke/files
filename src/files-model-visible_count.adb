separate (Files.Model)
   function Visible_Count
     (Model : Window_Model)
      return Natural
   is
      Count : Natural := 0;
   begin
      if not Model.Items.Is_Empty then
         for Item of Model.Items loop
            if Item_Is_Visible (Model, Item) then
               Count := Count + 1;
            end if;
         end loop;
      end if;

      if Temporary_Is_Visible (Model) then
         Count := Count + 1;
      end if;

      return Count;
   end Visible_Count;
