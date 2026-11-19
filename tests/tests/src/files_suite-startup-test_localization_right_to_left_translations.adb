separate (Files_Suite.Startup)
   --  The right-to-left interface locales, which draw the window mirrored,
   --  carry their own wording too: a command, an error and the status bar
   --  are not left in English, and their placeholders survive.
   procedure Test_Localization_Right_To_Left_Translations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Assert_Translated (Locale : String) is
         Small_Label : constant String := Files.Localization.Text ("command.view.small", Locale);
         Missing     : constant String := Files.Localization.Text ("error.path.missing", Locale);
         Hidden      : constant String := Files.Localization.Text ("status.hidden", Locale);
         Lines       : constant String :=
           Files.Localization.Text
             ("info.extra.text.lines",
              Files.Localization.Argument_List'
                [1 => (Ada.Strings.Unbounded.To_Unbounded_String ("lines"),
                       Ada.Strings.Unbounded.To_Unbounded_String ("42"))],
              Locale);
      begin
         Assert
           (Small_Label /= "Small Icons" and then Small_Label /= "command.view.small",
            Locale & " command label is translated");
         Assert
           (Missing /= "Path does not exist." and then Missing /= "error.path.missing",
            Locale & " error message is translated");
         Assert (Hidden /= "hidden" and then Hidden /= "status.hidden", Locale & " status word is translated");
         Assert
           (Ada.Strings.Fixed.Index (Lines, "42") > 0 and then Ada.Strings.Fixed.Index (Lines, "lines") = 0,
            Locale & " fills its placeholders in its own words: " & Lines);
      end Assert_Translated;
   begin
      Assert_Translated ("ar-EG");
      Assert_Translated ("fa-IR");
      Assert_Translated ("ur-PK");
      Assert_Translated ("he-IL");
      Assert_Translated ("yi");
   end Test_Localization_Right_To_Left_Translations;
