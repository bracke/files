separate (Files.File_System)
   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Settings.Sort_Field;
      Ascending : Boolean)
   is
      Count : constant Natural := Natural (Items.Length);
   begin
      if Count <= 1 then
         return;
      end if;

      declare
         --  Decorate-sort: the case-insensitive comparison recomputed To_Lower
         --  on both names for every one of the sort's O(N log N) comparisons.
         --  Here each item's lowercase keys are built once (N times), the sort
         --  reorders a cheap index permutation reading those keys, and the
         --  items are moved into place a single time at the end.
         type Sort_Key is record
            Name_Lower     : Unbounded_String;
            Filetype_Lower : Unbounded_String;
         end record;

         package Key_Vectors is new Ada.Containers.Vectors
           (Index_Type => Positive, Element_Type => Sort_Key);
         package Index_Vectors is new Ada.Containers.Vectors
           (Index_Type => Positive, Element_Type => Positive);

         --  Name_Lower is always needed -- it is the final tie-break for every
         --  field; Filetype_Lower only when sorting by filetype.
         Keys  : Key_Vectors.Vector;
         Order : Index_Vectors.Vector;

         function Name_Less (Left, Right : Positive) return Boolean is
         begin
            if Keys (Left).Name_Lower /= Keys (Right).Name_Lower then
               return Keys (Left).Name_Lower < Keys (Right).Name_Lower;
            else
               return Items (Left).Name < Items (Right).Name;
            end if;
         end Name_Less;

         function Text_Less (Left, Right : Positive) return Boolean is
         begin
            if Keys (Left).Filetype_Lower /= Keys (Right).Filetype_Lower then
               return Keys (Left).Filetype_Lower < Keys (Right).Filetype_Lower;
            else
               return Items (Left).Filetype < Items (Right).Filetype;
            end if;
         end Text_Less;

         function Less (Left, Right : Positive) return Boolean is
            Forward_Order : Boolean := False;
            Reverse_Order : Boolean := False;
         begin
            case Field is
               when Files.Settings.Sort_By_Name =>
                  Forward_Order := Name_Less (Left => Left, Right => Right);
                  Reverse_Order := Name_Less (Left => Right, Right => Left);
               when Files.Settings.Sort_By_Filetype =>
                  Forward_Order := Text_Less (Left => Left, Right => Right);
                  Reverse_Order := Text_Less (Left => Right, Right => Left);
               when Files.Settings.Sort_By_Size =>
                  if Items (Left).Size_Available /= Items (Right).Size_Available then
                     return Items (Left).Size_Available;
                  elsif Items (Left).Size /= Items (Right).Size then
                     Forward_Order := Items (Left).Size < Items (Right).Size;
                     Reverse_Order := Items (Right).Size < Items (Left).Size;
                  end if;
               when Files.Settings.Sort_By_Created =>
                  if Items (Left).Creation_Available /= Items (Right).Creation_Available then
                     return Items (Left).Creation_Available;
                  elsif Items (Left).Creation_Time /= Items (Right).Creation_Time then
                     Forward_Order := Items (Left).Creation_Time < Items (Right).Creation_Time;
                     Reverse_Order := Items (Right).Creation_Time < Items (Left).Creation_Time;
                  end if;
               when Files.Settings.Sort_By_Modified =>
                  if Items (Left).Modified_Available /= Items (Right).Modified_Available then
                     return Items (Left).Modified_Available;
                  elsif Items (Left).Modified_Time /= Items (Right).Modified_Time then
                     Forward_Order := Items (Left).Modified_Time < Items (Right).Modified_Time;
                     Reverse_Order := Items (Right).Modified_Time < Items (Left).Modified_Time;
                  end if;
            end case;

            if Field /= Files.Settings.Sort_By_Name
              and then not Forward_Order
              and then not Reverse_Order
            then
               return Name_Less (Left, Right);
            elsif Ascending then
               return Forward_Order;
            else
               return Reverse_Order;
            end if;
         end Less;

         package Sorting is new Index_Vectors.Generic_Sorting ("<" => Less);

         Sorted : Item_Vectors.Vector;
      begin
         Keys.Reserve_Capacity (Ada.Containers.Count_Type (Count));
         Order.Reserve_Capacity (Ada.Containers.Count_Type (Count));
         for Index in 1 .. Count loop
            declare
               Key : Sort_Key;
            begin
               Key.Name_Lower :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Items (Index).Name)));
               if Field = Files.Settings.Sort_By_Filetype then
                  Key.Filetype_Lower :=
                    To_Unbounded_String (Files.Types.To_Lower (To_String (Items (Index).Filetype)));
               end if;
               Keys.Append (Key);
            end;
            Order.Append (Index);
         end loop;

         --  Generic_Sorting is stable and Order starts ascending, so items that
         --  compare equal keep their original relative order -- matching the old
         --  in-place sort of Items exactly.
         Sorting.Sort (Order);

         Sorted.Reserve_Capacity (Ada.Containers.Count_Type (Count));
         for Index of Order loop
            Sorted.Append (Items (Index));
         end loop;

         Item_Vectors.Move (Target => Items, Source => Sorted);
      end;
   end Sort_Items;
