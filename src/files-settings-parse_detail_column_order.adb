separate (Files.Settings)
   function Parse_Detail_Column_Order
     (Value : String;
      Order : out Files.Types.Detail_Column_Order)
      return Boolean
   is
      use type Files.Types.Detail_Column;
      Seen  : array (Files.Types.Detail_Column) of Boolean := [others => False];
      Slot  : Natural := 0;
      First : Positive := Value'First;
      Column : Files.Types.Detail_Column;
   begin
      Order := Files.Types.Default_Detail_Column_Order;
      if Value'Length = 0 then
         return False;
      end if;

      for Index in Value'First .. Value'Last + 1 loop
         if Index > Value'Last or else Value (Index) = ',' then
            declare
               Token : constant String :=
                 Files.Types.To_Lower (Trim (Value (First .. Index - 1)));
            begin
               if not Detail_Column_For_Order_Token (Token, Column)
                 or else Seen (Column)
               then
                  return False;
               end if;
               Seen (Column) := True;
               Slot := Slot + 1;
            end;
            First := Index + 1;
         end if;
      end loop;

      --  Every column must appear exactly once for a valid permutation.
      if Slot /= Files.Types.Detail_Column_Count then
         return False;
      end if;
      for Column_Value in Files.Types.Detail_Column loop
         if not Seen (Column_Value) then
            return False;
         end if;
      end loop;

      --  Rebuild with name pinned to the first slot, preserving the optional
      --  columns' relative order as listed.
      Order (1) := Files.Types.Name_Column;
      Slot := 1;
      First := Value'First;
      for Index in Value'First .. Value'Last + 1 loop
         if Index > Value'Last or else Value (Index) = ',' then
            declare
               Token : constant String :=
                 Files.Types.To_Lower (Trim (Value (First .. Index - 1)));
            begin
               if Detail_Column_For_Order_Token (Token, Column)
                 and then Column /= Files.Types.Name_Column
               then
                  Slot := Slot + 1;
                  Order (Slot) := Column;
               end if;
            end;
            First := Index + 1;
         end if;
      end loop;

      return True;
   end Parse_Detail_Column_Order;
