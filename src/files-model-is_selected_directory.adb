separate (Files.Model)
   function Is_Selected_Directory
     (Model : Window_Model;
      Path  : String)
      return Boolean is
      use type Files.Types.Item_Kind;
   begin
      for Item of Selected_Items (Model) loop
         if Item.Kind = Files.Types.Directory_Item
           and then To_String (Item.Full_Path) = Path
         then
            return True;
         end if;
      end loop;
      return False;
   end Is_Selected_Directory;
