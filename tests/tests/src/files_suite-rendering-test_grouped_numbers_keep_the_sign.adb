with Files.Display_Text;
separate (Files_Suite.Rendering)
   procedure Test_Grouped_Numbers_Keep_The_Sign (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      type Long_Long_Integer_Array is array (Positive range <>) of Long_Long_Integer;
   begin
      --  Whatever the locale groups with, a negative number is the positive
      --  one with a minus in front ("-123", never "-,123").
      for Value of Long_Long_Integer_Array'(123, 1_234, 123_456, 1_234_567, 1_000_000_000) loop
         Files_Suite.Support.Assert_Equal
           (Files.Display_Text.Grouped_Integer_Text (-Value),
            "-" & Files.Display_Text.Grouped_Integer_Text (Value),
            "the sign stays outside the groups");
      end loop;
   end Test_Grouped_Numbers_Keep_The_Sign;
