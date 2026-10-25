separate (Files_Suite.Commands)
   procedure Test_Command_Identifiers_Registered (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal (Files.Commands.Command_Count, 73, "all expected commands are registered");
      Assert (Files.Commands.Contains ("status.free_space_toggle"),
              "free/used-space toggle command identifier is registered");
      Assert (Files.Commands.Contains ("navigate.recent"), "recent-view command identifier is registered");
      Assert (Files.Commands.Contains ("search.contents"), "content-search command identifier is registered");
      Assert (Files.Commands.Contains ("recent.clear"), "clear-recent command identifier is registered");
      Assert (Files.Commands.Contains ("label.set"), "set-color-label command identifier is registered");
      Assert (Files.Commands.Contains ("edit.copy_path"), "copy-path command identifier is registered");
      Assert
        (Files.Commands.Contains ("navigate.containing"),
         "open-containing-folder command identifier is registered");
      Assert (Files.Commands.Contains ("navigate.parent"), "navigate-parent command identifier is registered");
      Assert (Files.Commands.Contains ("favorite.toggle"), "favorite-toggle command identifier is registered");
      Assert
        (not Files.Commands.Contains ("bookmark.toggle"),
         "the renamed bookmark identifier is no longer registered");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Identifier (Files.Commands.Toggle_Favorite_Command),
         "favorite.toggle",
         "the favorite command reports its renamed identifier");
      Assert
        (Files.Commands.Requires_Settings_Path (Files.Commands.Toggle_Favorite_Command),
         "the favorite command routes through the settings-path persistence seam");
      Assert (Files.Commands.Contains ("file.copy_to"), "copy-to command identifier is registered");
      Assert (Files.Commands.Contains ("file.move_to"), "move-to command identifier is registered");
      Assert (Files.Commands.Contains ("tree.toggle"), "toggle-folder-tree command identifier is registered");
      Assert (Files.Commands.Contains ("terminal.open"), "open-terminal command identifier is registered");
      Assert (Files.Commands.Contains ("link.symbolic"), "create-symlink command identifier is registered");
      Assert (Files.Commands.Contains ("link.hard"), "create-hard-link command identifier is registered");
      Assert (Files.Commands.Contains ("file.compress_zip"), "compress-zip command identifier is registered");
      Assert (Files.Commands.Contains ("file.compress_7z"), "compress-7z command identifier is registered");
      Assert (Files.Commands.Contains ("view.small"), "stable command identifier is registered");
      Assert (Files.Commands.Contains ("settings.toggle"), "settings command identifier is registered");
      Assert (Files.Commands.Contains ("sort.menu.toggle"), "sort menu command identifier is registered");
      Assert (Files.Commands.Contains ("sort.name"), "sort by name command identifier is registered");
      Assert (Files.Commands.Contains ("sort.size"), "sort by size command identifier is registered");
      Assert (Files.Commands.Contains ("sort.type"), "sort by type command identifier is registered");
      Assert (Files.Commands.Contains ("sort.created"), "sort by created command identifier is registered");
      Assert (Files.Commands.Contains ("sort.changed"), "sort by changed command identifier is registered");
      Assert (Files.Commands.Contains ("selection.select_all"), "select-all command identifier is registered");
      Assert (Files.Commands.Contains ("selection.invert"), "invert-selection command identifier is registered");
      Assert
        (Files.Commands.Contains ("selection.deselect_all"),
         "deselect-all command identifier is registered");
      Assert (Files.Commands.Contains ("settings.save"), "settings save command identifier is registered");
      Assert (Files.Commands.Contains ("settings.reset"), "settings reset command identifier is registered");
      Assert (Files.Commands.Contains ("drive.eject_selected"), "drive eject command identifier is registered");
      Assert
        (Files.Commands.Contains ("file.delete_permanently"),
         "permanent delete command identifier is registered");
      Assert
        (Files.Commands.Contains ("file.generate_thumbnails"),
         "thumbnail generation command identifier is registered");
      Assert
        (Files.Commands.Contains ("directory.search_recursive"),
         "recursive search command identifier is registered");
      Assert (not Files.Commands.Contains (""), "empty command identifier is not registered");
   end Test_Command_Identifiers_Registered;
