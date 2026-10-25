separate (Files_Suite.Settings)
   --  A fresh install's one seeded open action has to name a program the host
   --  running it actually has. It named xdg-open on every host, and since a
   --  configured action wins over the system default, that entry did not just
   --  fail on Windows and macOS -- it shadowed the working `start` and `open`
   --  fallbacks, so text files did not open at all. Runs on each CI host, so
   --  each branch is checked where it applies.
   procedure Test_Default_Open_Action_Suits_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Defaults : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Lookup   : constant Files.Settings.Action_Lookup_Result :=
        Files.Settings.Lookup_Open_Action (Defaults, "text/plain", Guikit.Input.No_Modifiers);
      Expected : constant String :=
        (case Hostkit.Host.Current is
            when Hostkit.Host.Windows => "cmd",
            when Hostkit.Host.MacOS   => "open",
            when others               => "xdg-open");
      Found_Executable : constant String := To_String (Lookup.Action.Executable);
   begin
      Assert (Lookup.Found, "a fresh install seeds an open action for text/plain");
      Assert
        (not Lookup.System_Fallback,
         "the seeded text/plain action is a configured action, not the system fallback");
      Files_Suite.Support.Assert_Equal
        (Found_Executable,
         Expected,
         "the seeded text/plain opener names a program this host has: expected "
         & Expected & ", found " & Found_Executable);
      Assert
        (Natural (Lookup.Action.Arguments.Length) > 0
           and then To_String (Lookup.Action.Arguments.Last_Element) = "{path}",
         "the seeded text/plain opener is handed the file to open");
   end Test_Default_Open_Action_Suits_The_Host;
