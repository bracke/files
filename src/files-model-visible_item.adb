separate (Files.Model)
   function Visible_Item
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Files.File_System.Directory_Item
   is
      Item_Index : constant Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      if Item_Index /= 0 then
         return Model.Items.Element (Positive (Item_Index));
      elsif Temporary_Is_Visible (Model) and then Visible_Index = Visible_Count (Model) then
         if Model.Temporary_Is_Directory then
            return Files.File_System.Make_Item
              (Parent_Path => Current_Path (Model),
               Name        => To_String (Model.Temporary_Name_Value),
               Kind        => Files.Types.Directory_Item);
         else
            return Files.File_System.Make_Item
              (Parent_Path => Current_Path (Model),
               Name        => To_String (Model.Temporary_Name_Value),
               Kind        => Files.Types.Regular_File_Item,
               Filetype    => "text/plain");
         end if;
      else
         return Files.File_System.Make_Item ("", "", Files.Types.Unknown_Item);
      end if;
   end Visible_Item;
