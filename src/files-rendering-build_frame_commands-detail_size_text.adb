separate (Files.Rendering.Build_Frame_Commands)
   function Detail_Size_Text (Item : Item_Snapshot) return UString is
      Unit_Index : Natural := 0;
      Divisor    : Long_Long_Integer := 1;
      Locale     : constant String := Files.Localization.System_Number_Locale;

      function Unit_Key return String is
      begin
         case Unit_Index is
            when 0 =>
               return "details.size.unit.bytes";
            when 1 =>
               return "details.size.unit.kib";
            when 2 =>
               return "details.size.unit.mib";
            when 3 =>
               return "details.size.unit.gib";
            when 4 =>
               return "details.size.unit.tib";
            when others =>
               return "details.size.unit.pib";
         end case;
      end Unit_Key;

      function Scaled_Number return String is
         Whole     : constant Long_Long_Integer := Item.Size / Divisor;
         Remainder : constant Long_Long_Integer := Item.Size mod Divisor;
         Tenths    : constant Long_Long_Integer :=
           Whole * 10 + ((Remainder * 10) + Divisor / 2) / Divisor;
      begin
         return Localized_Number_Text (Tenths, Unit_Index /= 0);
      end Scaled_Number;
   begin
      if not Item.Size_Available then
         return Null_Unbounded_String;
      end if;

      while Unit_Index < 5 and then Item.Size >= Divisor * 1024 loop
         Unit_Index := Unit_Index + 1;
         Divisor := Divisor * 1024;
      end loop;

      return
        To_Unbounded_String
          (Scaled_Number & " " & Files.Localization.Text (Unit_Key, Locale));
   end Detail_Size_Text;
