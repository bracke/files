separate (Files.Model)
   function Is_Selected
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Boolean is
      Item_Index : Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      if Item_Index = 0
        and then Temporary_Is_Visible (Model)
        and then Visible_Index = Visible_Count (Model)
      then
         Item_Index := Temporary_Item_Index;
      end if;

      return Selection_Contains (Model, Item_Index);
   end Is_Selected;
