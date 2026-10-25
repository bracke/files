separate (Files_Suite.Startup)
   procedure Test_Localization_Pane_Labels (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("missing.test.key"),
         "missing.test.key",
         "unknown localization key falls back to key text");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("info.name"),
         "Name",
         "info pane name label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("info.folder_size"),
         "Contents",
         "info pane folder-size label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("info.contents.items"),
         "items",
         "info pane folder-size item label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("info.contents.total"),
         "total",
         "info pane folder-size total label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("status.items"),
         "Items",
         "item-count label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("status.visible"),
         "visible",
         "visible-count label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("status.selected"),
         "selected",
         "selected-count label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("status.missing_metadata"),
         "Unavailable",
         "missing metadata fallback is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("accessibility.toolbar"),
         "Toolbar",
         "toolbar landmark is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("accessibility.main_view"),
         "Directory contents",
         "main-view landmark is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("accessibility.info_pane"),
         "Information pane",
         "info-pane landmark is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("accessibility.command_palette_search"),
         "Command search",
         "command-palette search label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("accessibility.quick_look"),
         "Quick Look preview",
         "Quick Look landmark is localized");
      Assert
        (Files.Localization.Text ("quick_look.empty") /= "quick_look.empty",
         "Quick Look empty-preview message is localized");
      Assert
        (Files.Localization.Text ("quick_look.truncated") /= "quick_look.truncated",
         "Quick Look truncated-preview message is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("accessibility.root_selector"),
         "Root locations",
         "root-selector landmark is localized");
      Assert
        (Files.Localization.Text ("accessibility.favorite_toggle.on")
           /= "accessibility.favorite_toggle.on",
         "path-bar favorite-toggle on-state label is localized");
      Assert
        (Files.Localization.Text ("accessibility.favorite_toggle.off")
           /= "accessibility.favorite_toggle.off",
         "path-bar favorite-toggle off-state label is localized");
   end Test_Localization_Pane_Labels;
