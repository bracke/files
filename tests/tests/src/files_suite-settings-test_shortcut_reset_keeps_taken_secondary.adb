separate (Files_Suite.Settings)
   --  Resetting a command whose built-in secondary another command now holds
   --  leaves that chord with its new owner: Redo gets Ctrl+Shift+Z back, not
   --  Ctrl+Y from under the command bound to it.
   procedure Test_Shortcut_Reset_Keeps_Taken_Secondary (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Clears the overrides this test sets, on an assertion failure too.
      Shortcuts : Files_Suite.Support.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      use type Files.Commands.Shortcut;
      Ctrl : constant Guikit.Input.Modifier_Set := [Guikit.Input.Control_Key => True, others => False];
      Ctrl_Shift : constant Guikit.Input.Modifier_Set :=
        [Guikit.Input.Control_Key | Guikit.Input.Shift_Key => True, others => False];
   begin
      Files.Commands.Reset_Shortcut_Overrides;
      Files.Commands.Set_Shortcut_Override (Files.Commands.Redo_Command, (True, Guikit.Input.Key_R, Ctrl_Shift));
      Files.Commands.Set_Shortcut_Override
        (Files.Commands.Toggle_Folder_Tree_Command, (True, Guikit.Input.Key_Y, Ctrl));
      Files.Commands.Clear_Shortcut_Override (Files.Commands.Redo_Command);
      Assert
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Y, Ctrl) = Files.Commands.Toggle_Folder_Tree_Command,
         "Ctrl+Y stays with the command it was bound to");
      Assert
        (Files.Commands.Shortcut_For (Files.Commands.Redo_Command)
           = Files.Commands.Default_Shortcut_For (Files.Commands.Redo_Command),
         "Redo is back on its default primary");
      Assert (not Files.Commands.Secondary_Shortcut_For (Files.Commands.Redo_Command).Present,
              "without the secondary that is now taken");

      --  With the chord free again, a reset brings the secondary back.
      Files.Commands.Clear_Shortcut_Override (Files.Commands.Toggle_Folder_Tree_Command);
      Files.Commands.Clear_Shortcut_Override (Files.Commands.Redo_Command);
      Assert (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_Y, Ctrl) = Files.Commands.Redo_Command,
              "a free secondary returns with the reset");
   end Test_Shortcut_Reset_Keeps_Taken_Secondary;
