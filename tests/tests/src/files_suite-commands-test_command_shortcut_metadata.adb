separate (Files_Suite.Commands)
   procedure Test_Command_Shortcut_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl              : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Small_Shortcut    : Files.Commands.Shortcut;
      Drive_Shortcut    : Files.Commands.Shortcut;
      Settings_Shortcut : Files.Commands.Shortcut;
      Empty_Shortcut    : Files.Commands.Shortcut;
      Delete_Secondary  : Files.Commands.Shortcut;
      Empty_Secondary   : Files.Commands.Shortcut;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Small_Shortcut := Files.Commands.Shortcut_For (Files.Commands.Select_Small_Icons_Command);
      Assert (Small_Shortcut.Present, "shortcut metadata marks small-icons shortcut present");
      Files_Suite.Support.Assert_Equal
        (Small_Shortcut.Key,
         Guikit.Input.Key_1,
         "shortcut metadata stores small-icons key");
      Assert (Small_Shortcut.Modifiers = Ctrl, "shortcut metadata stores small-icons modifiers");
      Drive_Shortcut := Files.Commands.Shortcut_For (Files.Commands.Select_Drive_Command);
      Assert (Drive_Shortcut.Present, "drive selector exposes shortcut metadata");
      Files_Suite.Support.Assert_Equal (Drive_Shortcut.Key, Guikit.Input.Key_D, "drive selector shortcut uses D");
      Assert (Drive_Shortcut.Modifiers = Ctrl, "drive selector shortcut uses Control");
      Settings_Shortcut := Files.Commands.Shortcut_For (Files.Commands.Toggle_Settings_Pane_Command);
      Assert (Settings_Shortcut.Present, "settings pane exposes shortcut metadata");
      Files_Suite.Support.Assert_Equal
        (Settings_Shortcut.Key,
         Guikit.Input.Key_Comma,
         "settings pane shortcut uses comma");
      Assert (Settings_Shortcut.Modifiers = Ctrl, "settings pane shortcut uses Control");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Placement_For (Files.Commands.Toggle_Settings_Pane_Command),
         Files.Commands.Command_Palette_Only,
         "settings command uses command-palette placement");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Description_Key (Files.Commands.Toggle_Settings_Pane_Command),
         "command.settings.toggle.description",
         "settings command description key is stable");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Shortcut_For (Files.Commands.Save_Settings_Command).Key,
         Guikit.Input.Key_S,
         "settings save command uses S shortcut metadata");
      Assert
        (not Files.Commands.Shortcut_For (Files.Commands.Reset_Settings_Command).Present,
         "settings reset command is palette-only");
      Assert
        (Files.Commands.Requires_Settings_Path (Files.Commands.Save_Settings_Command),
         "settings save requires a settings path");
      Assert
        (Files.Commands.Requires_Settings_Path (Files.Commands.Reset_Settings_Command),
         "settings reset saves the defaults, so it requires a settings path");
      Assert
        (Files.Commands.Persists_Global_Ui_State (Files.Commands.Sort_By_Size_Command),
         "a sort command persists its UI state");
      Assert
        (Files.Commands.Persists_Global_Ui_State (Files.Commands.Select_Details_Command),
         "a view-mode command persists its UI state");
      Empty_Shortcut := Files.Commands.Shortcut_For (Files.Commands.No_Command);
      Assert (not Empty_Shortcut.Present, "no-command exposes absent shortcut metadata");
      Empty_Secondary := Files.Commands.Secondary_Shortcut_For (Files.Commands.No_Command);
      Assert (not Empty_Secondary.Present, "no-command exposes absent secondary shortcut metadata");
      Delete_Secondary := Files.Commands.Secondary_Shortcut_For (Files.Commands.Delete_Selected_Items_Command);
      Assert (Delete_Secondary.Present, "delete command exposes secondary shortcut metadata");
      Files_Suite.Support.Assert_Equal
        (Delete_Secondary.Key,
         Guikit.Input.Key_Backspace,
         "delete secondary shortcut uses Backspace");
      Assert
        (Delete_Secondary.Modifiers = Guikit.Input.No_Modifiers,
         "delete secondary shortcut has no modifiers");
   end Test_Command_Shortcut_Metadata;
