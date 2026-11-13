separate (Check_All)
   procedure Check_Catalog_Baseline_Keys is
      Catalog : constant String := Root & "/share/files.catalog";
   begin
      Project_Tools.Files.Require_Contains
        (Catalog,
         "default_locale = en",
         "localization catalog must declare the default English locale");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.usage = ",
         "localization catalog must include CLI help text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.startup.window.ready = ",
         "localization catalog must include startup window labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.startup.error = ",
         "localization catalog must include startup error labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.window = ",
         "localization catalog must include runtime smoke labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.rectangles = ",
         "localization catalog must include runtime smoke rectangle labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.glyphs = ",
         "localization catalog must include runtime smoke glyph labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.missing_glyphs = ",
         "localization catalog must include runtime smoke missing-glyph labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.font = ",
         "localization catalog must include runtime smoke font labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.vertices = ",
         "localization catalog must include runtime smoke vertex labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.vulkan_status = ",
         "localization catalog must include runtime smoke Vulkan status labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.vulkan_result = ",
         "localization catalog must include runtime smoke Vulkan result labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.framebuffer_readback = ",
         "localization catalog must include runtime smoke framebuffer readback labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.frames_attempted = ",
         "localization catalog must include runtime smoke attempted-frame labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.frames_presented = ",
         "localization catalog must include runtime smoke presented-frame labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.framebuffer_hash = ",
         "localization catalog must include runtime smoke framebuffer hash labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.framebuffer_bytes = ",
         "localization catalog must include runtime smoke framebuffer byte-count labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.text_failed = ",
         "localization catalog must include runtime smoke text-failure diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.no_windows = ",
         "localization catalog must include runtime smoke no-window diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.no_display = ",
         "localization catalog must include runtime smoke display diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.no_vulkan = ",
         "localization catalog must include runtime smoke diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.ready = ",
         "localization catalog must include runtime smoke ready diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.requires_live_harness = ",
         "localization catalog must include live-smoke harness diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.path = ",
         "localization catalog must include CLI path help text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.option.runtime_smoke = ",
         "localization catalog must include runtime-smoke CLI option text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.option.live_smoke = ",
         "localization catalog must include live-smoke CLI option text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.option.settings = ",
         "localization catalog must include settings CLI option text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.option.help = ",
         "localization catalog must include help CLI option text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.view.small = ",
         "localization catalog must include command labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.view.small.description = ",
         "localization catalog must include command descriptions");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.palette.empty = ",
         "localization catalog must include command-palette empty-state text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.root.filesystem = ",
         "localization catalog must include root-selector labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.root.detail = ",
         "localization catalog must include root-selector detail formatting");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.empty_directory = ",
         "localization catalog must include directory empty-state text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.filter.placeholder = find",
         "localization catalog must include filter placeholder text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.items = ",
         "localization catalog must include item-count status labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.visible = ",
         "localization catalog must include visible-count status labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.selected = ",
         "localization catalog must include selected-count status labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.missing_metadata = ",
         "localization catalog must include missing-metadata fallback text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.info.name = ",
         "localization catalog must include info-pane labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.info.extra.directory.count = ",
         "localization catalog must include filetype-specific metadata labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.name = ",
         "localization catalog must include details-view column labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.size.unit.bytes = ",
         "localization catalog must include details-view size units");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.size.unit.kib = ",
         "localization catalog must include scaled KB details-view size unit");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.size.unit.mib = ",
         "localization catalog must include scaled MB details-view size unit");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.size.unit.gib = ",
         "localization catalog must include scaled GB details-view size unit");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.settings.title = ",
         "localization catalog must include settings pane labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.settings.help.open_action_command = ",
         "localization catalog must include settings field help text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.toolbar = ",
         "localization catalog must include accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.main_view = ",
         "localization catalog must include main-view accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.info_pane = ",
         "localization catalog must include info-pane accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.command_palette_search = ",
         "localization catalog must include command-palette accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.command_disabled = ",
         "localization catalog must include disabled command accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.root_selector = ",
         "localization catalog must include root-selector accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.path.missing = ",
         "localization catalog must include recoverable error messages");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.rename.disabled = ",
         "localization catalog must include rename enablement errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.open_action.execution = ",
         "localization catalog must include open-action execution errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.open_action.unsafe_placeholder = ",
         "localization catalog must include unsafe open-action placeholder errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.file.delete_permanently = ",
         "localization catalog must include permanent-delete command labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.file.generate_thumbnails = ",
         "localization catalog must include thumbnail-generation command labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.directory.search_recursive = ",
         "localization catalog must include recursive-search command labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.settings.save = ",
         "localization catalog must include settings persistence errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.settings.closed = ",
         "localization catalog must include settings pane state errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.window.create = ",
         "localization catalog must include window creation errors");
   end Check_Catalog_Baseline_Keys;
