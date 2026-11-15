separate (Check_All)
   procedure Check_Catalog_Baseline_Keys is
      Catalog : constant String := Root & "/share/files.catalog";
   begin
      --  Only what no src literal names: a key a src literal names is already
      --  required by the direct, indirect and command localization checks.
      Require_In_Text
        (Catalog,
         "default_locale = en",
         "localization catalog must declare the default English locale");
      Require_In_Text
        (Catalog,
         "en.command.view.small.description = ",
         "localization catalog must include command descriptions");
      Require_In_Text
        (Catalog,
         "en.filter.placeholder = find",
         "localization catalog must include filter placeholder text");
      Require_In_Text
        (Catalog,
         "en.status.items = ",
         "localization catalog must include item-count status labels");
      Require_In_Text
        (Catalog,
         "en.info.name = ",
         "localization catalog must include info-pane labels");
      Require_In_Text
        (Catalog,
         "en.info.extra.directory.count = ",
         "localization catalog must include filetype-specific metadata labels");
      Require_In_Text
        (Catalog,
         "en.details.size.unit.kib = ",
         "localization catalog must include scaled KB details-view size unit");
      Require_In_Text
        (Catalog,
         "en.details.size.unit.mib = ",
         "localization catalog must include scaled MB details-view size unit");
      Require_In_Text
        (Catalog,
         "en.details.size.unit.gib = ",
         "localization catalog must include scaled GB details-view size unit");
      Require_In_Text
        (Catalog,
         "en.accessibility.command_palette_search = ",
         "localization catalog must include command-palette accessibility labels");
      Require_In_Text
        (Catalog,
         "en.accessibility.command_disabled = ",
         "localization catalog must include disabled command accessibility labels");
      Require_In_Text
        (Catalog,
         "en.command.file.generate_thumbnails = ",
         "localization catalog must include thumbnail-generation command labels");
      Require_In_Text
        (Catalog,
         "en.error.settings.closed = ",
         "localization catalog must include settings pane state errors");
   end Check_Catalog_Baseline_Keys;
