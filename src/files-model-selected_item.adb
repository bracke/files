separate (Files.Model)
   function Selected_Item
     (Model : Window_Model)
      return Files.File_System.Directory_Item
   is
      Item_Index : constant Natural := Effective_Selected_Item_Index (Model);
   begin
      if Selected_Count (Model) = 0 then
         return Files.File_System.Make_Item ("", "", Files.Types.Unknown_Item);
      elsif Item_Index = Temporary_Item_Index then
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
      end if;

      return Model.Items.Element (Positive (Item_Index));
   end Selected_Item;
