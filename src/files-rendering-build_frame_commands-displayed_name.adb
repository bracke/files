separate (Files.Rendering.Build_Frame_Commands)
   function Displayed_Name (Item : Item_Snapshot) return UString is
      Name : constant String := To_String (Item.Name);
   begin
      if Snapshot.Show_Extensions or else Item.Kind = Files.Types.Directory_Item then
         return Item.Name;
      end if;
      for I in reverse Name'First + 1 .. Name'Last loop
         if Name (I) = '.' then
            return To_Unbounded_String (Name (Name'First .. I - 1));
         end if;
      end loop;
      return Item.Name;
   end Displayed_Name;
