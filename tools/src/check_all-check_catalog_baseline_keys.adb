separate (Check_All)
   procedure Check_Catalog_Baseline_Keys is
      Catalog : constant String := Root & "/share/files.catalog";
   begin
      Require_In_Text
        (Catalog,
         "default_locale = en",
         "localization catalog must declare the default English locale");
      Require_In_Text
        (Catalog,
         "en.cli.help.usage = ",
         "localization catalog must include CLI help text");
      Require_In_Text
        (Catalog,
         "en.startup.window.ready = ",
         "localization catalog must include startup window labels");
      Require_In_Text
        (Catalog,
         "en.startup.error = ",
         "localization catalog must include startup error labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.window = ",
         "localization catalog must include runtime smoke labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.rectangles = ",
         "localization catalog must include runtime smoke rectangle labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.glyphs = ",
         "localization catalog must include runtime smoke glyph labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.missing_glyphs = ",
         "localization catalog must include runtime smoke missing-glyph labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.font = ",
         "localization catalog must include runtime smoke font labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.vertices = ",
         "localization catalog must include runtime smoke vertex labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.vulkan_status = ",
         "localization catalog must include runtime smoke Vulkan status labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.vulkan_result = ",
         "localization catalog must include runtime smoke Vulkan result labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.framebuffer_readback = ",
         "localization catalog must include runtime smoke framebuffer readback labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.frames_attempted = ",
         "localization catalog must include runtime smoke attempted-frame labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.frames_presented = ",
         "localization catalog must include runtime smoke presented-frame labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.framebuffer_hash = ",
         "localization catalog must include runtime smoke framebuffer hash labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.framebuffer_bytes = ",
         "localization catalog must include runtime smoke framebuffer byte-count labels");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.text_failed = ",
         "localization catalog must include runtime smoke text-failure diagnostics");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.no_windows = ",
         "localization catalog must include runtime smoke no-window diagnostics");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.no_display = ",
         "localization catalog must include runtime smoke display diagnostics");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.no_vulkan = ",
         "localization catalog must include runtime smoke diagnostics");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.ready = ",
         "localization catalog must include runtime smoke ready diagnostics");
      Require_In_Text
        (Catalog,
         "en.runtime.smoke.requires_live_harness = ",
         "localization catalog must include live-smoke harness diagnostics");
      Require_In_Text
        (Catalog,
         "en.cli.help.path = ",
         "localization catalog must include CLI path help text");
      Require_In_Text
        (Catalog,
         "en.cli.help.option.runtime_smoke = ",
         "localization catalog must include runtime-smoke CLI option text");
      Require_In_Text
        (Catalog,
         "en.cli.help.option.live_smoke = ",
         "localization catalog must include live-smoke CLI option text");
      Require_In_Text
        (Catalog,
         "en.cli.help.option.settings = ",
         "localization catalog must include settings CLI option text");
      Require_In_Text
        (Catalog,
         "en.cli.help.option.help = ",
         "localization catalog must include help CLI option text");
      Require_In_Text
        (Catalog,
         "en.command.view.small = ",
         "localization catalog must include command labels");
      Require_In_Text
        (Catalog,
         "en.command.view.small.description = ",
         "localization catalog must include command descriptions");
      Require_In_Text
        (Catalog,
         "en.command.palette.empty = ",
         "localization catalog must include command-palette empty-state text");
      Require_In_Text
        (Catalog,
         "en.root.filesystem = ",
         "localization catalog must include root-selector labels");
      Require_In_Text
        (Catalog,
         "en.root.detail = ",
         "localization catalog must include root-selector detail formatting");
      Require_In_Text
        (Catalog,
         "en.status.empty_directory = ",
         "localization catalog must include directory empty-state text");
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
         "en.status.visible = ",
         "localization catalog must include visible-count status labels");
      Require_In_Text
        (Catalog,
         "en.status.selected = ",
         "localization catalog must include selected-count status labels");
      Require_In_Text
        (Catalog,
         "en.status.missing_metadata = ",
         "localization catalog must include missing-metadata fallback text");
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
         "en.details.name = ",
         "localization catalog must include details-view column labels");
      Require_In_Text
        (Catalog,
         "en.details.size.unit.bytes = ",
         "localization catalog must include details-view size units");
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
         "en.settings.title = ",
         "localization catalog must include settings pane labels");
      Require_In_Text
        (Catalog,
         "en.settings.help.open_action_command = ",
         "localization catalog must include settings field help text");
      Require_In_Text
        (Catalog,
         "en.accessibility.toolbar = ",
         "localization catalog must include accessibility labels");
      Require_In_Text
        (Catalog,
         "en.accessibility.main_view = ",
         "localization catalog must include main-view accessibility labels");
      Require_In_Text
        (Catalog,
         "en.accessibility.info_pane = ",
         "localization catalog must include info-pane accessibility labels");
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
         "en.accessibility.root_selector = ",
         "localization catalog must include root-selector accessibility labels");
      Require_In_Text
        (Catalog,
         "en.error.path.missing = ",
         "localization catalog must include recoverable error messages");
      Require_In_Text
        (Catalog,
         "en.error.rename.disabled = ",
         "localization catalog must include rename enablement errors");
      Require_In_Text
        (Catalog,
         "en.error.open_action.execution = ",
         "localization catalog must include open-action execution errors");
      Require_In_Text
        (Catalog,
         "en.error.open_action.unsafe_placeholder = ",
         "localization catalog must include unsafe open-action placeholder errors");
      Require_In_Text
        (Catalog,
         "en.command.file.delete_permanently = ",
         "localization catalog must include permanent-delete command labels");
      Require_In_Text
        (Catalog,
         "en.command.file.generate_thumbnails = ",
         "localization catalog must include thumbnail-generation command labels");
      Require_In_Text
        (Catalog,
         "en.command.directory.search_recursive = ",
         "localization catalog must include recursive-search command labels");
      Require_In_Text
        (Catalog,
         "en.error.settings.save = ",
         "localization catalog must include settings persistence errors");
      Require_In_Text
        (Catalog,
         "en.error.settings.closed = ",
         "localization catalog must include settings pane state errors");
      Require_In_Text
        (Catalog,
         "en.error.window.create = ",
         "localization catalog must include window creation errors");
   end Check_Catalog_Baseline_Keys;
