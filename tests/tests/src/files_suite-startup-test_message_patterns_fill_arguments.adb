separate (Files_Suite.Startup)
   --  A message pattern takes its punctuation from the locale: a details
   --  row's description for screen readers joins label and value with ": "
   --  and the fields with ", " in English, puts a space before the colon in
   --  French, and a locale without the patterns borrows the default locale's.
   procedure Test_Message_Patterns_Fill_Arguments (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function U (Text : String) return Ada.Strings.Unbounded.Unbounded_String
        renames Ada.Strings.Unbounded.To_Unbounded_String;

      --  Two fields, each a label and a value, joined as Locale does.
      function Fields (Locale : String) return String is
        (Files.Localization.Text
           ("accessibility.item.fields",
            Files.Localization.Argument_List'
              [(U ("first"), U (Files.Localization.Label_Value ("M", "today", Locale))),
               (U ("rest"), U (Files.Localization.Label_Value ("S", "3 KB", Locale)))],
            Locale));
   begin
      Assert_Equal (Fields ("en"), "M: today, S: 3 KB", "English joins with a colon and a comma");
      Assert_Equal (Fields ("fr"), "M : today, S : 3 KB", "French puts a space before the colon");
      Assert_Equal (Fields ("af"), "M: today, S: 3 KB", "a locale without the pattern takes the default locale's");
   end Test_Message_Patterns_Fill_Arguments;
