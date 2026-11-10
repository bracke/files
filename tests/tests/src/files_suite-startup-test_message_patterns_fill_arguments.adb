separate (Files_Suite.Startup)
   --  A message pattern takes its punctuation from the locale: an item's
   --  description for screen readers joins label and value with ": " in
   --  English and " : " in French, and a locale without the pattern borrows
   --  the default locale's.
   procedure Test_Message_Patterns_Fill_Arguments (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function U (Text : String) return Ada.Strings.Unbounded.Unbounded_String
        renames Ada.Strings.Unbounded.To_Unbounded_String;
      Values : constant Files.Localization.Argument_List :=
        [(U ("modified_label"), U ("M")), (U ("modified"), U ("today")),
         (U ("size_label"), U ("S")), (U ("size"), U ("3 KB")),
         (U ("type_label"), U ("T")), (U ("type"), U ("text"))];
   begin
      Assert_Equal
        (Files.Localization.Text ("accessibility.item.details", Values, "en"),
         "M: today, S: 3 KB, T: text", "English joins with a colon and a comma");
      Assert_Equal
        (Files.Localization.Text ("accessibility.item.details", Values, "fr"),
         "M : today, S : 3 KB, T : text", "French puts a space before the colon");
      Assert_Equal
        (Files.Localization.Text ("accessibility.item.details", Values, "af"),
         "M: today, S: 3 KB, T: text", "a locale without the pattern takes the default locale's");
   end Test_Message_Patterns_Fill_Arguments;
