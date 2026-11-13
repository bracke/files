separate (Check_All)
   procedure Check_Application_CLI_Surface is
      Application_Spec : constant String := Root & "/src/files-application.ads";
      Application_Body : constant String := Root & "/src/files-application.adb";
      Tests            : constant String := Combined_Suite;
   begin
      Require_Not_Contains_In_Unit
        (Root & "/src/files-rendering.adb",
         "Unit_Width - 1",
         "text glyph rendering must not half-shift wide Unicode filename glyphs");
      Project_Tools.Files.Require_Contains
        (Root & "/share/files.catalog",
         "en.cli.help.option.version = ",
         "localized catalog must include version help text");
   end Check_Application_CLI_Surface;
