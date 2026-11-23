with Files.Commands.Testing;
separate (Files_Suite.Commands)
   procedure Test_Command_Identifiers_Registered (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Natural'(Files.Commands.Registered_Command_Id'Pos (Files.Commands.Registered_Command_Id'Last)
           - Files.Commands.Registered_Command_Id'Pos (Files.Commands.Registered_Command_Id'First) + 1),
         73,
         "all expected commands are registered");
      Assert (Files.Commands.Testing.Contains ("status.free_space_toggle"),
              "free/used-space toggle command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("navigate.recent"), "recent-view command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("search.contents"), "content-search command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("recent.clear"), "clear-recent command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("label.set"), "set-color-label command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("edit.copy_path"), "copy-path command identifier is registered");
      Assert
        (Files.Commands.Testing.Contains ("navigate.containing"),
         "open-containing-folder command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("navigate.parent"), "navigate-parent command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("favorite.toggle"), "favorite-toggle command identifier is registered");
      Assert
        (not Files.Commands.Testing.Contains ("bookmark.toggle"),
         "the renamed bookmark identifier is no longer registered");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Identifier (Files.Commands.Toggle_Favorite_Command),
         "favorite.toggle",
         "the favorite command reports its renamed identifier");
      Assert
        (Files.Commands.Requires_Settings_Path (Files.Commands.Toggle_Favorite_Command),
         "the favorite command routes through the settings-path persistence seam");
      Assert (Files.Commands.Testing.Contains ("file.copy_to"), "copy-to command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("file.move_to"), "move-to command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("tree.toggle"), "toggle-folder-tree command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("terminal.open"), "open-terminal command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("link.symbolic"), "create-symlink command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("link.hard"), "create-hard-link command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("file.compress_zip"), "compress-zip command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("file.compress_7z"), "compress-7z command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("view.small"), "stable command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("settings.toggle"), "settings command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("sort.menu.toggle"), "sort menu command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("sort.name"), "sort by name command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("sort.size"), "sort by size command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("sort.type"), "sort by type command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("sort.created"), "sort by created command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("sort.changed"), "sort by changed command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("selection.select_all"), "select-all command identifier is registered");
      Assert
        (Files.Commands.Testing.Contains ("selection.invert"), "invert-selection command identifier is registered");
      Assert
        (Files.Commands.Testing.Contains ("selection.deselect_all"),
         "deselect-all command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("settings.save"), "settings save command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("settings.reset"), "settings reset command identifier is registered");
      Assert (Files.Commands.Testing.Contains ("drive.eject_selected"), "drive eject command identifier is registered");
      Assert
        (Files.Commands.Testing.Contains ("file.delete_permanently"),
         "permanent delete command identifier is registered");
      Assert
        (Files.Commands.Testing.Contains ("file.generate_thumbnails"),
         "thumbnail generation command identifier is registered");
      Assert
        (Files.Commands.Testing.Contains ("directory.search_recursive"),
         "recursive search command identifier is registered");
      Assert (not Files.Commands.Testing.Contains (""), "empty command identifier is not registered");
   end Test_Command_Identifiers_Registered;
