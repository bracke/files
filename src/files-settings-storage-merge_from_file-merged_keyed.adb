separate (Files.Settings.Storage.Merge_From_File)
   function Merged_Keyed (Base, Mine, Theirs : Vectors.Vector) return Vectors.Vector is
      Result : Vectors.Vector;
      Placed : Key_Sets.Set;

      --  Each key's first entry in List, read once.
      function Index (List : Vectors.Vector) return Key_Indexes.Map is
         Map : Key_Indexes.Map;
      begin
         for Position in List.First_Index .. List.Last_Index loop
            declare
               Key : constant String := Key_Of (List (Position));
            begin
               if not Map.Contains (Key) then
                  Map.Insert (Key, Position);
               end if;
            end;
         end loop;
         return Map;
      end Index;

      In_Base : constant Key_Indexes.Map := Index (Base);
      In_Mine : constant Key_Indexes.Map := Index (Mine);

      --  Whether this process changed what Key says since Base.
      function Changed (Key : String) return Boolean is
         Was_There : constant Boolean := In_Base.Contains (Key);
         Is_There  : constant Boolean := In_Mine.Contains (Key);
      begin
         return Was_There /= Is_There
           or else (Was_There
                    and then Base (In_Base.Element (Key)) /= Mine (In_Mine.Element (Key)));
      end Changed;

      procedure Place (Key : String; Item : Element) is
      begin
         Result.Append (Item);
         Placed.Include (Key);
      end Place;
   begin
      for Item of Theirs loop
         declare
            Key : constant String := Key_Of (Item);
         begin
            if not Changed (Key) then
               Place (Key, Item);
            elsif not Placed.Contains (Key) and then In_Mine.Contains (Key) then
               --  This process's entry in the file's place; none if it
               --  removed it.
               Place (Key, Mine (In_Mine.Element (Key)));
            end if;
         end;
      end loop;
      for Own of Mine loop
         declare
            Key : constant String := Key_Of (Own);
         begin
            if Changed (Key) and then not Placed.Contains (Key) then
               Place (Key, Own);
            end if;
         end;
      end loop;
      return Result;
   end Merged_Keyed;
