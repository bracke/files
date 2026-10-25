separate (Files_Suite.Commands)
   procedure Test_Shortcut_Overrides (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Clears the overrides this test sets, on an assertion failure too.
      Shortcuts : Files_Suite.Support.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      Ctrl       : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Files.Commands.Reset_Shortcut_Overrides;
      Ctrl (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;

      --  Parsing is the inverse of the formatter.
      declare
         Parsed : constant Files.Commands.Shortcut := Files.Commands.Parse_Shortcut ("control+1");
      begin
         Assert (Parsed.Present and then Parsed.Key = Guikit.Input.Key_1, "control+1 parses to the 1 key");
         Assert (Parsed.Modifiers (Guikit.Input.Control_Key)
                 and then not Parsed.Modifiers (Guikit.Input.Shift_Key),
                 "control+1 parses only the control modifier");
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Text_To_Key ("f5"),
         Guikit.Input.Key_F5,
         "text-to-key maps a function key");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Text_To_Key ("nope"),
         Guikit.Input.Key_Unknown,
         "unrecognised text yields Key_Unknown");
      --  Keys added by the keycode expansion round-trip too.
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Text_To_Key ("e"),
         Guikit.Input.Key_E,
         "a newly-added letter key parses");
      declare
         S : constant Files.Commands.Shortcut := Files.Commands.Parse_Shortcut ("control+shift+f7");
      begin
         Assert (S.Present, "control+shift+f7 parses the expanded function key with both modifiers (present)");
         Files_Suite.Support.Assert_Equal
           (S.Key, Guikit.Input.Key_F7,
            "control+shift+f7 parses the expanded function key with both modifiers (key)");
         Assert
           (S.Modifiers (Guikit.Input.Control_Key),
            "control+shift+f7 parses the expanded function key with both modifiers (Control)");
         Assert
           (S.Modifiers (Guikit.Input.Shift_Key),
            "control+shift+f7 parses the expanded function key with both modifiers (Shift)");
         --  Shown to people with the language's modifier names (the suite runs
         --  in English); the stored form above is unchanged.
         Files_Suite.Support.Assert_Equal
           (Files.Commands.Shortcut_Display_Text (S),
            "Ctrl+Shift+F7",
            "a shortcut reads as Ctrl+Shift+F7, not control+shift+f7");
         Files_Suite.Support.Assert_Equal
           (Files.Commands.Shortcut_Display_Text (Files.Commands.Parse_Shortcut ("control+pagedown")),
            "Ctrl+Page Down",
            "named keys read by their catalog names");
         Files_Suite.Support.Assert_Equal
           (Files.Commands.Shortcut_Text (S),
            "shift+control+f7",
            "the stored form stays parseable");
      end;

      --  Defaults still resolve, and an override rebinds a chord to a command.
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_1, Ctrl),
         Files.Commands.Select_Small_Icons_Command,
         "ctrl+1 defaults to small icons");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_B, Ctrl_Shift),
         Files.Commands.No_Command,
         "ctrl+shift+b is unbound by default");
      Files.Commands.Set_Shortcut_Override
        (Files.Commands.Toggle_Show_Extensions_Command,
         (Present => True, Key => Guikit.Input.Key_B, Modifiers => Ctrl_Shift));
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_B, Ctrl_Shift),
         Files.Commands.Toggle_Show_Extensions_Command,
         "an override binds the chosen chord to its command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Shortcut_For (Files.Commands.Toggle_Show_Extensions_Command).Key,
         Guikit.Input.Key_B,
         "Shortcut_For resolves to the override");

      --  Clearing reverts to the default (here, no shortcut).
      Files.Commands.Clear_Shortcut_Override (Files.Commands.Toggle_Show_Extensions_Command);
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_B, Ctrl_Shift),
         Files.Commands.No_Command,
         "clearing the override unbinds the chord");
      Assert (not Files.Commands.Shortcut_For (Files.Commands.Toggle_Show_Extensions_Command).Present,
              "the command has no default shortcut after clearing");

      --  Id_For_Identifier maps a stable identifier back to its command, and
      --  reports No_Command for an unknown identifier (the seam the persisted
      --  [shortcuts] section uses to reapply overrides at startup).
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Id_For_Identifier ("view.small"),
         Files.Commands.Select_Small_Icons_Command,
         "Id_For_Identifier resolves a known identifier");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Id_For_Identifier ("no.such.command"),
         Files.Commands.No_Command,
         "Id_For_Identifier reports No_Command for an unknown identifier");
   end Test_Shortcut_Overrides;
