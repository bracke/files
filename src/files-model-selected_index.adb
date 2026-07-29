separate (Files.Model)
   function Selected_Index
     (Model : Window_Model)
      return Natural is
   begin
      if Model.Selected_Item_Index = Temporary_Item_Index then
         if Temporary_Is_Visible (Model) then
            return Visible_Count (Model);
         end if;

         return 0;
      end if;

      if Model.Selected_Item_Index = 0 then
         return 0;
      end if;

      return Item_To_Visible_Index (Model, Positive (Model.Selected_Item_Index));
   end Selected_Index;
