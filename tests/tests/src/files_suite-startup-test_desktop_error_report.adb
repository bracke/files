separate (Files_Suite.Startup)
   procedure Test_Desktop_Error_Report (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Expected : constant String :=
        Files.Localization.Text ("startup.error") & ": " & Files.Localization.Text ("error.window.create");
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Application.Desktop_Error_Report ("error.window.create"),
         Expected,
         "desktop error report localizes the provided key");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Desktop_Error_Report (""),
         Expected,
         "desktop error report falls back when the key is empty");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Desktop_Error_Report ("error.window.unknown"),
         Expected,
         "desktop error report falls back when the key is not localized");
   end Test_Desktop_Error_Report;
