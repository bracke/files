separate (Files_Suite.Settings)
   --  A built-in secondary shortcut is part of the default binding: rebinding
   --  or unbinding the command drops it, and a chord held only by another
   --  command's secondary can be bound elsewhere (that command keeps its
   --  primary).
   procedure Test_Secondary_Shortcut_Overrides (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package SP renames Guikit.Settings_Panel;
      package GI renames Guikit.Input;

      Model : Files.Model.Window_Model;
      Saved : Boolean;
      Ctrl  : constant GI.Modifier_Set := [GI.Control_Key => True, others => False];

      function Change (Key, Value : String) return SP.Change is
        ((Kind => SP.Value_Changed, Key => To_Unbounded_String (Key), Value => To_Unbounded_String (Value)));

      function Text (Chord : String) return String is
        (Files.Commands.Shortcut_Text (Files.Commands.Parse_Shortcut (Chord)));
   begin
      Files.Commands.Reset_Shortcut_Overrides;
      Files.Model.Begin_Settings_Edit
        (Model, Files.Settings.Make_Draft (Files.Settings.Default_Settings));

      --  By default Backspace deletes too.
      Assert (Files.Commands.Find_By_Shortcut (GI.Key_Backspace, GI.No_Modifiers)
              = Files.Commands.Delete_Selected_Items_Command,
              "Backspace is Delete's built-in secondary");

      --  Unbinding Delete clears both of its bindings.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.file.delete_selected", ""));
      Assert (Saved, "unbinding Delete saves");
      Assert (not Files.Commands.Secondary_Shortcut_For (Files.Commands.Delete_Selected_Items_Command).Present,
              "an unbound command has no secondary either");
      Assert (Files.Commands.Find_By_Shortcut (GI.Key_Backspace, GI.No_Modifiers) = Files.Commands.No_Command,
              "Backspace no longer deletes once Delete is unbound");

      --  Back to the default restores the secondary.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.file.delete_selected", Text ("delete")));
      Assert (Saved, "restoring Delete's default saves");
      Assert (Files.Commands.Find_By_Shortcut (GI.Key_Backspace, GI.No_Modifiers)
              = Files.Commands.Delete_Selected_Items_Command,
              "the default binding brings Backspace back");

      --  Ctrl+Y is only Redo's secondary, so it can be bound to Undo; Redo
      --  keeps its primary.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.edit.undo", Text ("control+y")));
      Assert (Saved, "a chord held only by a secondary is not a conflict");
      Assert (Files.Commands.Find_By_Shortcut (GI.Key_Y, Ctrl) = Files.Commands.Undo_Command,
              "Ctrl+Y now runs Undo");
      Assert (Files.Commands."="
                (Files.Commands.Shortcut_For (Files.Commands.Redo_Command),
                 Files.Commands.Default_Shortcut_For (Files.Commands.Redo_Command)),
              "Redo keeps its primary shortcut");
      Assert (not Files.Commands.Secondary_Shortcut_For (Files.Commands.Redo_Command).Present,
              "Redo gave up its secondary");

      --  A live primary still conflicts.
      Saved := Files.Settings_Form.Apply (Model, Change ("shortcut.edit.undo", Text ("control+c")));
      Assert (not Saved, "another command's primary is a conflict");
      Assert (Files.Commands.Find_By_Shortcut (GI.Key_C, Ctrl) = Files.Commands.Copy_Selected_Items_Command,
              "Ctrl+C still copies after the rejected rebind");

      Files.Commands.Reset_Shortcut_Overrides;
   end Test_Secondary_Shortcut_Overrides;
