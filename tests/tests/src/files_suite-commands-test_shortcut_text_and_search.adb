separate (Files_Suite.Commands)
   procedure Test_Shortcut_Text_And_Search (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Files.Commands.Open_Command_Palette_Command)),
         "control+p",
         "primary shortcut text is normalized");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Files.Commands.Toggle_Settings_Pane_Command)),
         "control+,",
         "settings shortcut text includes comma");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Delete_Selected_Items_Command),
            "delete") = 1,
         "command shortcut search text keeps canonical delete shortcut first");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Delete_Selected_Items_Command),
            "del") > 0,
         "command shortcut search text includes delete shortcut alias");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Delete_Selected_Items_Command),
            "backspace") > 0,
         "command shortcut search text includes secondary shortcuts");
      Assert
        (Files.Commands.Shortcut_Text
           (Files.Commands.Shortcut_For (Files.Commands.Delete_Selected_Permanently_Command)) =
         "shift+delete",
         "permanent delete shortcut text is normalized");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Delete_Selected_Permanently_Command),
            "shift+delete") = 1,
         "permanent delete shortcut search text keeps canonical shortcut first");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Open_Command_Palette_Command),
            "control+p") = 1,
         "command shortcut search text keeps canonical primary shortcut first");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Open_Command_Palette_Command),
            "ctrl+p") > 0,
         "command shortcut search text includes control shortcut alias");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Navigate_Back_Command),
            "option+left") > 0,
         "command shortcut search text includes option shortcut alias");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Close_Command_Palette_Command),
            "esc") > 0,
         "command shortcut search text includes escape shortcut alias");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.Commands.Shortcut_Search_Text (Files.Commands.Open_Selected_Items_Command),
            "enter") > 0,
         "command shortcut search text includes return shortcut alias");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Shortcut_Search_Text (Files.Commands.No_Command),
         "",
         "no-command has no shortcut search text");
   end Test_Shortcut_Text_And_Search;
