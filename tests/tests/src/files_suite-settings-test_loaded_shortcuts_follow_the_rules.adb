with Files.Commands.Keymap_Settings;
separate (Files_Suite.Settings)
   --  Shortcut overrides read from settings are bound by the keymap's rules
   --  (Commands.Rebind), as an edit in the pane is: overrides merged from
   --  two processes that put two commands on one chord leave it with the
   --  first, the other keeping its default binding; an override equal to
   --  the default is no override; and a chord one entry gives up is free
   --  for another, whatever their order.
   procedure Test_Loaded_Shortcuts_Follow_The_Rules (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package GI renames Guikit.Input;
      use type Files.Commands.Shortcut;

      Ctrl : constant GI.Modifier_Set := [GI.Control_Key => True, others => False];

      function Override (Command, Combo : String) return Files.Settings.Shortcut_Override is
        ((Command => To_Unbounded_String (Command),
          Combo   => To_Unbounded_String (Files.Commands.Shortcut_Text (Files.Commands.Parse_Shortcut (Combo)))));

      function Map_Of (Overrides : Files.Settings.Shortcut_Override_Vectors.Vector) return Files.Commands.Keymap is
        (Files.Commands.Keymap_Settings.Keymap_Of (Overrides));

      --  Whether Overrides_Of (Map) holds an entry for Command.
      function Stored (Map : Files.Commands.Keymap; Command : String) return Boolean is
      begin
         for Entry_Value of Files.Commands.Keymap_Settings.Overrides_Of (Map) loop
            if To_String (Entry_Value.Command) = Command then
               return True;
            end if;
         end loop;
         return False;
      end Stored;

      Overrides : Files.Settings.Shortcut_Override_Vectors.Vector;
      Map       : Files.Commands.Keymap;
   begin
      --  Two commands merged onto Ctrl+K: the first listed keeps it.
      Overrides.Append (Override ("edit.undo", "control+k"));
      Overrides.Append (Override ("file.delete_selected", "control+k"));
      Map := Map_Of (Overrides);
      Assert (Files.Commands.Find_By_Shortcut (Map, GI.Key_K, Ctrl) = Files.Commands.Undo_Command,
              "the first override listed keeps the merged chord");
      Assert (Files.Commands.Shortcut_For (Map, Files.Commands.Delete_Selected_Items_Command)
              = Files.Commands.Default_Shortcut_For (Files.Commands.Delete_Selected_Items_Command),
              "the clashing one keeps its default binding");
      Assert (Files.Commands.Find_By_Shortcut (Map, GI.Key_Backspace, GI.No_Modifiers)
              = Files.Commands.Delete_Selected_Items_Command,
              "its built-in secondary included");
      Assert (Stored (Map, "edit.undo") and then not Stored (Map, "file.delete_selected"),
              "only the override in force is written back");

      --  An override equal to the default is no override: the command keeps
      --  its whole default binding, secondary and all.
      Overrides.Clear;
      Overrides.Append (Override ("edit.redo", "control+shift+z"));
      Map := Map_Of (Overrides);
      Assert (not Stored (Map, "edit.redo"), "an override equal to the default is not kept");
      Assert (Files.Commands.Find_By_Shortcut (Map, GI.Key_Y, Ctrl) = Files.Commands.Redo_Command,
              "and the default's secondary stays");

      --  An override onto another command's default primary is refused.
      Overrides.Clear;
      Overrides.Append (Override ("edit.undo", "control+c"));
      Map := Map_Of (Overrides);
      Assert (Files.Commands.Find_By_Shortcut (Map, GI.Key_C, Ctrl) = Files.Commands.Copy_Selected_Items_Command,
              "Ctrl+C stays Copy's");
      Assert (Files.Commands.Find_By_Shortcut (Map, GI.Key_Z, Ctrl) = Files.Commands.Undo_Command,
              "Undo keeps its default");

      --  Copy moves off Ctrl+C and Undo takes it: listed in either order,
      --  both hold.
      for Undo_First in Boolean loop
         Overrides.Clear;
         if Undo_First then
            Overrides.Append (Override ("edit.undo", "control+c"));
            Overrides.Append (Override ("file.copy", "control+k"));
         else
            Overrides.Append (Override ("file.copy", "control+k"));
            Overrides.Append (Override ("edit.undo", "control+c"));
         end if;
         Map := Map_Of (Overrides);
         Assert (Files.Commands.Find_By_Shortcut (Map, GI.Key_C, Ctrl) = Files.Commands.Undo_Command,
                 "a chord another override frees is free for Undo (undo first: " & Undo_First'Image & ")");
         Assert (Files.Commands.Find_By_Shortcut (Map, GI.Key_K, Ctrl)
                 = Files.Commands.Copy_Selected_Items_Command,
                 "and Copy has its new chord (undo first: " & Undo_First'Image & ")");
      end loop;
   end Test_Loaded_Shortcuts_Follow_The_Rules;
