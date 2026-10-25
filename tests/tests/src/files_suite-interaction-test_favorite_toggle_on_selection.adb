separate (Files_Suite.Interaction)
   procedure Test_Favorite_Toggle_On_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Path     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "favorites.conf");
      Item     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "Alpha.txt");
      Action   : constant Files.Events.Input_Action :=
        (Kind    => Files.Events.Command_Input_Action,
         Command => Files.Commands.Toggle_Favorite_Command,
         others  => <>);
   begin
      Files_Suite.Support.Reset_Root;

      --  Selected file: favoriting stores the item's full path, not the folder.
      Files_Suite.Support.Select_Name (Model, "Alpha.txt");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "the sample file is selected before favoriting");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (Has_Favorite (Settings, Item), "favoriting a selected file stores its path");
      Assert (Result.Settings_Changed, "favoriting reports a settings change");

      Files.Interaction.Apply_Input_Action
        (Model,
         Settings,
         Path,
         (Kind => Files.Events.No_Input_Action, others => <>),
         Base_Font,
         Guikit.Input.No_Modifiers,
         Result);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Controller.Controller_Ignored,
         "a reused interaction result does not retain follow-up flags from the prior action (status)");
      Files_Suite.Support.Assert_Equal
        (Result.Command, Files.Commands.No_Command,
         "a reused interaction result does not retain follow-up flags from the prior action (command)");
      Assert
        (not Result.Command_Executed,
         "a reused interaction result does not retain follow-up flags from the prior action (command executed)");
      Assert
        (not Result.Settings_Changed,
         "a reused interaction result does not retain follow-up flags from the prior action (settings changed)");
      Assert
        (not Result.Font_Size_Changed,
         "a reused interaction result does not retain follow-up flags from the prior action (font size changed)");
      Assert
        (not Result.Needs_Glyph_Rebuild,
         "a reused interaction result does not retain follow-up flags from the prior action (needs glyph rebuild)");
      Assert
        (not Result.Directory_Reloaded,
         "a reused interaction result does not retain follow-up flags from the prior action (directory reloaded)");
      Assert
        (not Result.Clear_Pending_Text,
         "a reused interaction result does not retain follow-up flags from the prior action (clear pending text)");
      Assert
        (not Result.Context_Menu_Changed,
         "a reused interaction result does not retain follow-up flags from the prior action (context menu changed)");

      --  Toggling the same selection again removes the favorite.
      Files.Interaction.Apply_Input_Action
        (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert (not Has_Favorite (Settings, Item), "toggling the selected file again removes its favorite");

      --  No selection: the toggle falls back to the current directory.
      Files.Model.Deselect_All (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "the selection is cleared for the fallback path");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert
        (Has_Favorite (Settings, Files.Model.Current_Path (Model)),
         "with no selection the toggle favorites the current folder");

      --  A selected inline-create placeholder has no filesystem path. It must
      --  not be confused with the empty-selection fallback and toggle the
      --  current directory behind the active editor.
      Files.Interaction.Apply_Input_Action
        (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert
        (not Has_Favorite (Settings, Files.Model.Current_Path (Model)),
         "the setup removes the current-folder favorite");
      Files.Model.Begin_Create_File (Model, "untitled.txt");
      Assert
        (Files.Model.Selection_Includes_Temporary (Model),
         "the pending create row is selected before the favorite command");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Toggle_Favorite_Command, Model),
         "favorite is disabled for a temporary selection");
      Files.Interaction.Apply_Input_Action
        (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      Assert
        (not Has_Favorite (Settings, Files.Model.Current_Path (Model)),
         "favoriting a temporary row does not toggle the current folder");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.create.pending"
         and then not Result.Settings_Changed,
         "the rejected favorite reports the pending create without persisting settings");
   end Test_Favorite_Toggle_On_Selection;
