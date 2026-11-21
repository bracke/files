with Files.Name_Parts;

separate (Files.Rendering.Build_Frame_Commands)
   function Displayed_Name (Item : Item_Snapshot) return UString is
      Name : constant String := To_String (Item.Name);
   begin
      if Snapshot.Show_Extensions or else Item.Kind = Files.Types.Directory_Item then
         return Item.Name;
      end if;
      --  The one rule for where an extension starts: "..." and "draft."
      --  have none, so they show whole.
      return To_Unbounded_String (Files.Name_Parts.Stem_Of (Name));
   end Displayed_Name;
