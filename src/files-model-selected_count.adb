separate (Files.Model)
   function Selected_Count
     (Model : Window_Model)
      return Natural is
   begin
      if not Model.Selected_Item_Indexes.Is_Empty then
         return Natural (Model.Selected_Item_Indexes.Length);
      elsif Selected_Index (Model) /= 0 then
         return 1;
      else
         return 0;
      end if;
   end Selected_Count;
