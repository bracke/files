separate (Files_Suite.Settings)
   --  Persisted shortcut overrides survive a settings text round-trip, including
   --  a rebind, a rebind carrying modifiers, and an explicit unbind (empty
   --  combo). A malformed hand-edited entry is skipped without failing the load.
   procedure Test_Shortcut_Overrides_Persist (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Combo_For (Settings : Files.Settings.Settings_Model; Command : String) return String is
      begin
         for Entry_Value of Settings.Shortcut_Overrides loop
            if To_String (Entry_Value.Command) = Command then
               return To_String (Entry_Value.Combo);
            end if;
         end loop;
         return "<absent>";
      end Combo_For;

      Source : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      Assert (Source.Shortcut_Overrides.Is_Empty, "a fresh model has no shortcut overrides");

      Source.Shortcut_Overrides.Append
        (Files.Settings.Shortcut_Override'
           (Command => To_Unbounded_String ("view.small"),
            Combo   => To_Unbounded_String ("control+shift+1")));
      --  An explicit unbind is stored with an empty combo.
      Source.Shortcut_Overrides.Append
        (Files.Settings.Shortcut_Override'
           (Command => To_Unbounded_String ("navigate.home"),
            Combo   => To_Unbounded_String ("")));

      declare
         Reloaded : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse (Files.Settings.To_Text (Source));
      begin
         Assert (Reloaded.Success, "shortcut settings text parses");
         Files_Suite.Support.Assert_Equal
           (Natural (Reloaded.Settings.Shortcut_Overrides.Length),
            2,
            "both shortcut overrides round-trip");
         Files_Suite.Support.Assert_Equal
           (Combo_For (Reloaded.Settings, "view.small"),
            "control+shift+1",
            "a modifier-bearing rebind round-trips");
         Files_Suite.Support.Assert_Equal
           (Combo_For (Reloaded.Settings, "navigate.home"),
            "",
            "an explicit unbind round-trips as an empty combo");
      end;

      --  A hand-edited entry without the '|' separator is skipped, not fatal.
      declare
         Text : constant String :=
           "[shortcuts]" & ASCII.LF &
           "shortcut = ""view.small|control+shift+1""" & ASCII.LF &
           "shortcut = ""malformed-no-separator""" & ASCII.LF;
         Parsed : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse (Text);
      begin
         Assert (Parsed.Success, "a malformed shortcut line does not fail the load");
         Files_Suite.Support.Assert_Equal
           (Natural (Parsed.Settings.Shortcut_Overrides.Length),
            1,
            "only the well-formed shortcut entry is kept");
         Files_Suite.Support.Assert_Equal
           (Combo_For (Parsed.Settings, "view.small"),
            "control+shift+1",
            "the well-formed entry survives alongside the skipped one");
      end;
   end Test_Shortcut_Overrides_Persist;
