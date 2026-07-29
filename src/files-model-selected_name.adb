separate (Files.Model)
   function Selected_Name
     (Model : Window_Model)
      return String
   is
      Item_Index : constant Natural := Effective_Selected_Item_Index (Model);
   begin
      if Selected_Count (Model) = 0 then
         return "";
      elsif Item_Index = Temporary_Item_Index then
         return To_String (Model.Temporary_Name_Value);
      end if;

      return To_String (Model.Items.Element (Positive (Item_Index)).Name);
   end Selected_Name;
