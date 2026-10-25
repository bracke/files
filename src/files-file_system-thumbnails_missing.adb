separate (Files.File_System)
function Thumbnails_Missing (Items : Item_Vectors.Vector) return Boolean is
begin
   for Item of Items loop
      if not Item.Thumbnail_Available
        and then Should_Auto_Generate_Thumbnail
          (Item.Kind, To_String (Item.Filetype), To_String (Item.Name), To_String (Item.Icon_Id))
      then
         return True;
      end if;
   end loop;
   return False;
end Thumbnails_Missing;
