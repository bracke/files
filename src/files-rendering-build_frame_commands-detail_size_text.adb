separate (Files.Rendering.Build_Frame_Commands)
   function Detail_Size_Text (Item : Item_Snapshot) return UString is
   begin
      if not Item.Size_Available then
         return Null_Unbounded_String;
      end if;

      return To_Unbounded_String (Size_Text (Item.Size));
   end Detail_Size_Text;
