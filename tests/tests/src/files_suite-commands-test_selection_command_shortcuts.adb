separate (Files_Suite.Commands)
   procedure Test_Selection_Command_Shortcuts (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl       : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;
      Assert
        (Same_Shortcut
           (Files.Commands.Shortcut_For (Files.Commands.Invert_Selection_Command),
            (True, Guikit.Input.Key_I, Ctrl)),
         "invert-selection uses Control+I");
      Assert
        (Same_Shortcut
           (Files.Commands.Shortcut_For (Files.Commands.Deselect_All_Command),
            (True, Guikit.Input.Key_A, Ctrl_Shift)),
         "deselect-all uses Control+Shift+A");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_I, Ctrl),
         Files.Commands.Invert_Selection_Command,
         "Control+I resolves to invert-selection command");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Find_By_Shortcut (Guikit.Input.Key_A, Ctrl_Shift),
         Files.Commands.Deselect_All_Command,
         "Control+Shift+A resolves to deselect-all command");
   end Test_Selection_Command_Shortcuts;
