separate (Files_Suite.Startup)
   procedure Test_Localization_Western_Translations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      procedure Assert_Western_Translation
        (Locale : String)
      is
         Small_Label : constant String := Files.Localization.Text ("command.view.small", Locale);
         Missing     : constant String := Files.Localization.Text ("error.path.missing", Locale);
      begin
         Assert
           (Small_Label /= "Small Icons" and then Small_Label /= "command.view.small",
            Locale & " command label is translated");
         Assert
           (Missing /= "Path does not exist." and then Missing /= "error.path.missing",
            Locale & " error message is translated");
         Assert
           (Files.Localization.Text ("status.items", Locale) /= "status.items",
            Locale & " status label resolves from catalog");
      end Assert_Western_Translation;
   begin
      Assert_Western_Translation ("da-DK");
      Assert_Western_Translation ("de-DE");
      Assert_Western_Translation ("es-ES");
      Assert_Western_Translation ("fr-FR");
      Assert_Western_Translation ("it-IT");
      Assert_Western_Translation ("nl-NL");
      Assert_Western_Translation ("pt-PT");
      Assert_Western_Translation ("sv-SE");
      Assert_Western_Translation ("nb-NO");
      Assert_Western_Translation ("fi-FI");
   end Test_Localization_Western_Translations;
