separate (Files_Suite.Startup)
   procedure Test_Localization_Runtime_Labels (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("command.view.small"),
         "Small Icons",
         "known command label is loaded from catalog");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("startup.window.ready"),
         "Window",
         "startup window label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("startup.error"),
         "Error",
         "startup error label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.window"),
         "Runtime smoke window",
         "runtime smoke window label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.rectangles"),
         "rectangles",
         "runtime smoke rectangle label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.glyphs"),
         "glyphs",
         "runtime smoke glyph label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.missing_glyphs"),
         "missing glyphs",
         "runtime smoke missing-glyph label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.font"),
         "font",
         "runtime smoke font label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.vertices"),
         "vertices",
         "runtime smoke vertex label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.vulkan_status"),
         "Vulkan status",
         "runtime smoke Vulkan status label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.vulkan_result"),
         "Vulkan result",
         "runtime smoke Vulkan result label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("command.selection.select_all"),
         "Select All",
         "select-all command label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.framebuffer_readback"),
         "framebuffer readback",
         "runtime smoke framebuffer readback label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.frames_attempted"),
         "frames attempted",
         "runtime smoke attempted-frame label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.frames_presented"),
         "frames presented",
         "runtime smoke presented-frame label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.framebuffer_hash"),
         "framebuffer hash",
         "runtime smoke framebuffer hash label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.framebuffer_bytes"),
         "framebuffer bytes",
         "runtime smoke framebuffer byte-count label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.text_failed"),
         "Runtime smoke text rendering failed.",
         "runtime smoke text-failure label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.no_windows"),
         "Runtime smoke has no windows.",
         "runtime smoke no-window label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.no_display"),
         "Runtime smoke needs a live display.",
         "runtime smoke no-display label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.no_vulkan"),
         "Runtime smoke needs Vulkan support.",
         "runtime smoke no-Vulkan label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.ready"),
         "Runtime smoke is ready.",
         "runtime smoke ready label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("runtime.smoke.requires_live_harness"),
         "Runtime smoke requires a live harness.",
         "runtime smoke live-harness label is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("cli.help.usage"),
         "Usage: files [OPTION]... [PATH...]",
         "CLI help usage is localized");
      Files_Suite.Support.Assert_Equal
        (Files.Localization.Text ("cli.help.path"),
         "PATH opens a directory, or the parent directory of a file.",
         "CLI help path description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.runtime_smoke"), "--runtime-smoke") > 0,
         "CLI help runtime smoke description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.live_smoke"), "--live-smoke") > 0,
         "CLI help live smoke description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.settings"), "--settings PATH") > 0,
         "CLI help settings description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.version"), "--version") > 0,
         "CLI help version description is localized");
      Assert
        (Ada.Strings.Fixed.Index (Files.Localization.Text ("cli.help.option.help"), "--help, -h") > 0,
         "CLI help flag description is localized");
   end Test_Localization_Runtime_Labels;
