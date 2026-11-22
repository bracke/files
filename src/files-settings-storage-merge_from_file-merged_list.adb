separate (Files.Settings.Storage.Merge_From_File)
   function Merged_List
     (Base, Mine, Theirs : String_Vectors.Vector;
      Seed               : String_Vectors.Vector := String_Vectors.Empty_Vector;
      Cap                : Natural := Natural'Last)
      return String_Vectors.Vector
   is
      In_Base : constant Item_Sets.Set := Members (Base);
      In_Mine : constant Item_Sets.Set := Members (Mine);
      Placed  : Item_Sets.Set := Members (Seed);
      Result  : String_Vectors.Vector := Seed;

      procedure Place (Item : Unbounded_String) is
      begin
         if not Placed.Contains (Item) then
            Result.Append (Item);
            Placed.Insert (Item);
         end if;
      end Place;
   begin
      for Item of Theirs loop
         exit when Natural (Result.Length) >= Cap;
         if not (In_Base.Contains (Item) and then not In_Mine.Contains (Item)) then
            Place (Item);
         end if;
      end loop;
      for Item of Mine loop
         exit when Natural (Result.Length) >= Cap;
         if not In_Base.Contains (Item) then
            Place (Item);
         end if;
      end loop;
      return Result;
   end Merged_List;
